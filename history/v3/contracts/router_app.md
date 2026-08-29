# Smart Contract Deep-Dive: `router_app.py`

## 1. Architectural Model & Execution Pipeline

`contracts/router_app.py` is the on-chain core of the smart routing engine. It executes multi-hop trades through heterogeneous AMMs (Tinyman v2, Pact, STAMM, AlgoFi) where intermediate amounts are determined dynamically on-chain.

```
Caller Transfer (T_in)
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│ Router Application (contracts/router_app.py)             │
│                                                          │
│  1. _assert_group_is_clean()                             │
│  2. _input_amount() & _assert_input_spent()              │
│  3. _signed_floor() -> Quoted Minimum Output             │
│  4. _open_holding() -> Borrow MBR                        │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Leg 1: _swap_leg() -> Deposit -> AMM Call -> Delta │  │
│  └────────────────────────┬───────────────────────────┘  │
│                           ▼                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │ (Optional) _skim() -> Skim ALGO platform fee       │  │
│  └────────────────────────┬───────────────────────────┘  │
│                           ▼                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Leg 2: _swap_leg() -> Deposit -> AMM Call -> Delta │  │
│  └────────────────────────┬───────────────────────────┘  │
│                           ▼                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │ (Optional) Leg 3 (route3): _swap_leg()             │  │
│  └────────────────────────┬───────────────────────────┘  │
│                           ▼                              │
│  5. _group_paid() >= minimum_received                    │
│  6. _pay_out(Txn.sender) & Close Temporary Holdings      │
└───────────────────────────┬──────────────────────────────┘
                            ▼
Caller Receives Final Output Tokens (T_out)
```

---

## 2. State Storage & Data Structures

### Global State Schema
- `admin` (`Account`): Administrative account authorized for parameter updates and contract deletion.
- `platform_escrow` (`Account`): Destination account for converted `ASASTATS` fees.
- `fee_bps` (`UInt64`): Protocol fee rate in basis points ($\le 100$).
- `accrued` (`UInt64`): Accumulated unconverted ALGO platform revenue in microALGO.
- `voucher_signer` (`Bytes`): 32-byte Ed25519 public key for discount vouchers.
- `quote_signer` (`Account`): Account whose co-signature authenticates quote floors.
- `conversion_pool` (`Bytes`): 56-byte encoded `Leg` struct for treasury conversions.

### Struct: `Leg` (56 bytes ARC-4 Encoded)
```python
class Leg(arc4.Struct):
    provider: arc4.UInt64   # 0=Tinyman v2, 1=Pact, 2=STAMM, 3=AlgoFi
    app: arc4.UInt64        # Pool Application ID (Pact, STAMM, AlgoFi)
    tier: arc4.UInt64       # STAMM tier index
    asset_a: arc4.UInt64    # Pool base asset ID
    asset_b: arc4.UInt64    # Pool quote asset ID
    hub: arc4.UInt64        # AlgoFi manager Application ID
    opups: arc4.UInt64      # STAMM budget opcode request count (<= 8)
```

---

## 3. Detailed Method Verification

### 3.1 Administrative Methods
- `set_admin(admin: Account)`: Gated to `Txn.sender == self.admin`; rejects `Global.zero_address`.
- `set_escrow(escrow: Account)`: Gated to `Txn.sender == self.admin`; rejects zero address; verifies `FEE_ASSET_ID` opt-in.
- `set_fee(fee_bps: UInt64)`: Gated to `Txn.sender == self.admin`; enforces `fee_bps <= 100`.
- `set_voucher_signer(public_key: Bytes)`: Gated to admin; enforces `length == 32`.
- `set_quote_signer(signer: Account)`: Gated to admin; rejects zero address (rotation only).
- `set_conversion_pool(leg: Leg)`: Gated to admin; records 56-byte Leg struct.

### 3.2 Routing Endpoints
- `route(...)` and `route3(...)`:
  1. Clean group scan (`_assert_group_is_clean`).
  2. Temporary admin gate check (`RESTRICT_TO_ADMIN`).
  3. Asset distinctness assertions.
  4. Adjacent input validation (`_input_amount`).
  5. Floor authentication (`_signed_floor`).
  6. Dynamic MBR opt-in loans (`_open_holding`).
  7. Sequential leg execution via balance deltas (`_swap_leg`).
  8. Input conservation check (`_assert_input_spent`).
  9. ALGO fee skimming (`_skim`).
  10. Group-wide floor assertion (`_group_paid`).
  11. Payout and immediate holding close-out.

### 3.3 Treasury Endpoint
- `convert_and_distribute(batch: UInt64, minimum_out: UInt64)`:
  1. Admin only.
  2. Rejects same-group approval (`_assert_no_conversion_pool_approval`).
  3. Checks `batch <= self.accrued`.
  4. Bounds: `MIN_CONVERSION_BATCH <= batch <= MAX_CONVERSION_BATCH` (except sub-floor dust sweep).
  5. Enforces `minimum_out > 0` (except sub-floor dust sweep).
  6. Executes swap through `self.conversion_pool`.
  7. Deducts `batch` from `self.accrued`.
  8. Transfers `ASASTATS` to `platform_escrow` and closes temporary holding.
