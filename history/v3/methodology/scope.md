# Smart Router Security Audit Scope (v3)

## 1. Audit Target & Identification

The subject of this comprehensive security review is the ASA Stats Smart Router application and its contract integration boundary.

- **Primary Contract File:** `router/contracts/router_app.py`
- **Language / Framework:** Algorand Python (`algopy`), Puya compiler v5.9.0
- **Compiled Bytecode Artifacts:**
  - Approval Program: `Router.approval.teal` (TEAL v11, 4,641 lines substituted)
  - Clear State Program: `Router.clear.teal` (TEAL v11, 3 instructions: `pushint 1; return`)
  - Application Specification: `Router.arc56.json` (ARC-56 compliant ABI spec)
- **Deployment Target:** Algorand Mainnet / Testnet / LocalNet

## 2. In-Scope Components

1. **Smart Contract Codebase (`contracts/router_app.py`):**
   - Application initialization and state management (`__init__`)
   - Administrative methods (`set_admin`, `set_escrow`, `set_fee`, `set_voucher_signer`, `set_quote_signer`, `set_conversion_pool`)
   - Route execution endpoints (`route`, `route3`)
   - Treasury fee conversion & distribution (`convert_and_distribute`)
   - Off-chain voucher signature verification (`verify_discount`, `_discount`)
   - Dynamic opcode pooling (`pool_budget`)
   - Temporary holding lifecycle & MBR management (`opt_in_asset`, `close_holding`, `_open_holding`, `_pay_out`)
   - Application lifecycle (`delete_application`)
   - Core subroutines (`_assert_group_is_clean`, `_signed_floor`, `_group_paid`, `_logged_output`, `_routed_in_group`, `_opened_in_group`, `_assert_no_conversion_pool_approval`, `_held`, `_assert_created_by`, `_assert_listed`, `_swap_leg`, `_tinyman_v2_pool`, `_tinyman_v2_leg`, `_pact_leg`, `_algofi_leg`, `_stamm_leg`, `_skim`, `_input_amount`, `_assert_input_spent`, `_pay`)

2. **Cross-AMM Composition Layer & Adapters:**
   - Tinyman v2 logic signature derivation and invocation
   - Pact AMM pool application calls and positional asset arrays
   - STAMM Stratified AMM budget allocation, opcode pooling, and multi-tier swap calls
   - AlgoFi pool whitelisting and manager application validation

3. **Cryptographic & Group Security Schemes:**
   - Backend Ed25519 discount voucher authorization scheme (`verify_discount`)
   - Co-signed quote floor note scheme (`_signed_floor`)
   - Atomic group cleanliness validation against rekeying and close-out drains

4. **Static & Dynamic Analysis:**
   - Tealer 0.1.2 static analyzer detectors and covered proofs
   - Trail of Bits 11-pattern Algorand vulnerability scanner
   - Pytest unit, integration, LocalNet, and Hypothesis fuzz testing suites

## 3. Deployment Template Variables

The smart contract uses compile-time template variables to pin critical security parameters and network-specific constants without runtime gas overhead:

| Template Variable | Type | Mainnet Value | Security Purpose |
|---|---|---|---|
| `RESTRICT_TO_ADMIN` | `UInt64` | `0` (Prod) / `1` (Test) | Gates `route`/`route3` to admin during verification |
| `TINYMAN_V2_APP_ID` | `UInt64` | `1002541853` | Pins Tinyman v2 validator application ID |
| `FEE_ASSET_ID` | `UInt64` | `393537671` (ASASTATS) | Target asset for platform fee conversions |
| `MIN_CONVERSION_BATCH` | `UInt64` | `10_000` (0.01 ALGO) | Economic floor below which fee conversion is disallowed (except sub-floor final sweep) |
| `PACT_POOL_CREATORS` | `Bytes` | 64 bytes (2 creators) | Pinned creator addresses for legitimate Pact AMM pools |
| `STAMM_POOL_CREATORS` | `Bytes` | 32 bytes (1 creator) | Pinned creator address for legitimate STAMM AMM pools |
| `STAMM_BUDGET_APP_ID` | `UInt64` | `1002541853` (or network id) | Application ID for STAMM budget inner-tx spawner |
| `STAMM_OPUP_APP_ID` | `UInt64` | Target network app ID | Application ID for STAMM opcode budget target |
| `ALGOFI_MANAGER_APP_ID` | `UInt64` | Target network manager ID | Pinned manager application for AlgoFi pools |
| `ALGOFI_POOLS` | `Bytes` | Concatenated 8-byte IDs | Whitelist of curated, liquid AlgoFi pool application IDs |

## 4. Out-of-Scope Boundaries

The following components are outside the formal verification boundaries of this on-chain audit, except where their interaction directly affects the on-chain security guarantees:
- Off-chain quote search and graph exploration algorithms (Stages 0–3)
- Off-chain route allocation and numerical simulation engines
- Frontend user interfaces and mobile wallet bridge software (analyzed solely from the perspective of threat modeling adversarial inputs to the contract)
- Internal economic math and smart contracts of external third-party DEXes (Pact, Tinyman, STAMM, AlgoFi) — treated as black-box external protocols
