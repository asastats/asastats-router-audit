# Cross-Contract Interactions & DEX Interfaces (v5)

This document maps all external application calls and asset transfers issued by the router to third-party DEX protocols.

---

## 1. Interaction Call Graph

```
                            [ Router Application ]
                                       │
        ┌──────────────┬───────────────┼───────────────┬──────────────┐
        │              │               │               │              │
        ▼              ▼               ▼               ▼              ▼
   [ Tinyman v2 ]  [ Pact Std ]   [ Pact MWPT ]   [   STAMM   ]   [  AlgoFi   ]
   (LogicSig Pool) (App + Escrow) (App + Vault)   (App + Hub)     (App + Mgr)
```

---

## 2. Protocol Integration Specifications

### 2.1 Tinyman v2 Integration
- **Pool Addressing:** Derived on-chain by hashing the standard Tinyman v2 logic signature template with the two asset IDs.
- **Deposit / Call Flow:**
  - 1. Inner AssetTransfer / Payment to derived LogicSig pool account (`fee=0`).
  - 2. Inner ApplicationCall to Tinyman v2 validator application (`fee=0`, args: `["swap", "fixed-input"]`).
- **Output Delivery:** Tinyman v2 credits swap output directly to the caller (the router).

### 2.2 Pact Standard & Stableswap Integration
- **Pool Authentication:** Pool application creator verified against `PACT_POOL_CREATORS`.
- **Deposit / Call Flow:**
  - 1. Inner AssetTransfer / Payment to pool application address (`fee=0`).
  - 2. Inner ApplicationCall to pool application (`fee=0`, args: `["SWAP", 0]`, assets: `[asset_a, asset_b]`).
- **Output Delivery:** Pact transfers output tokens directly back to the router.

### 2.3 Pact MWPT (Managed Weighted Pool) Integration
- **Pool Authentication:** Pool creator verified against official MWPT factory address `H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM`.
- **Dynamic Vault Resolution:** Router queries pool global state key `vault` via `op.AppGlobal.get_ex_uint64(pool_app, b"vault")` and verifies vault address on-chain.
- **Deposit / Call Flow:**
  - 1. Inner AssetTransfer / Payment directed to the verified **Vault address** (`fee=0`).
  - 2. Inner ApplicationCall to pool application (`fee=0`, selector: `0x035942b0`, args: `[PACT_MWPT_SWAP, 0]`).

### 2.4 STAMM Integration
- **Pool Authentication:** Pool application creator verified against `STAMM_POOL_CREATORS`.
- **Opup & Tier Dispatch:**
  - 1. Inner ApplicationCall to STAMM Budget application providing requested opups ($\le 8$).
  - 2. Inner ApplicationCall to STAMM pool application with split tier deposit allocations.

### 2.5 AlgoFi Integration
- **Pool Authentication:** Pool application ID verified against immutable compiled list of 23 active AlgoFi pool IDs (`ALGOFI_POOLS`). Manager app ID verified against `ALGOFI_MANAGER_APP_ID`.
- **Deposit / Call Flow:**
  - 1. Inner AssetTransfer / Payment to pool address (`fee=0`).
  - 2. Inner ApplicationCall to pool application (`fee=0`, args: `["SEF", 0]`).
