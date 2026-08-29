# Global State Keys & Schema Analysis (v5)

The ASA Stats Smart Router utilizes a compact global state schema containing 7 state variables.

---

## 1. Global State Schema Inventory

| Key Name | Storage Type | Algorand Type | Mutability | Mutating Methods | Description |
|----------|:------------:|:-------------:|:----------:|:----------------:|-------------|
| `admin` | Global State | `Account` (bytes32) | Admin Only | `set_admin` | Administrative account holding upgrade/setter authority |
| `platform_escrow` | Global State | `Account` (bytes32) | Admin Only | `set_escrow` | Destination account receiving converted ASASTATS fees |
| `fee_bps` | Global State | `UInt64` | Admin Only | `set_fee` | Platform fee rate in basis points (capped at $\le 100$) |
| `accrued` | Global State | `UInt64` | Swap / Admin | `_skim`, `convert_and_distribute` | Total microALGO fees skimmed and awaiting conversion |
| `quote_signer` | Global State | `Account` (bytes32) | Admin Only | `set_quote_signer` | Public key authorizing group slippage floor notes |
| `voucher_signer` | Global State | `Account` (bytes32) | Admin Only | `set_voucher_signer` | Public key authorizing fee discount vouchers |
| `conversion_pool`| Global State | `Bytes` | Admin Only | `set_conversion_pool` | Serialized `Leg` struct describing the approved treasury pool |

---

## 2. Storage Allocation & Limits

- **Global Ints:** 2 (`fee_bps`, `accrued`)
- **Global Bytes:** 5 (`admin`, `platform_escrow`, `quote_signer`, `voucher_signer`, `conversion_pool`)
- **Local State:** None (0 ints, 0 bytes)
- **Box Storage:** None (0 boxes; eliminates box MBR growth attacks)
- **Minimum Balance Requirement (MBR):** Base application MBR is fixed at deployment and does not grow dynamically.
