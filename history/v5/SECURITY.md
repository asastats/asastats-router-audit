# Smart Router Security Policy & Threat Model (v5)

## 1. Security Architecture & Threat Model

The ASA Stats Smart Router executes under a zero-trust multi-party threat model:

```
+-----------------------------------------------------------------------------------------+
|                                THREAT MODEL MATRIX (v5)                                 |
+----------------------+--------------------+---------------------------------------------+
| Actor / Role         | Trust Level        | Threat Boundary & Enforced Defenses         |
+----------------------+--------------------+---------------------------------------------+
| End User / Caller    | Untrusted          | - Cannot rekey or close accounts            |
|                      |                    | - Cannot steal operational float            |
|                      |                    | - Input must immediately precede call       |
+----------------------+--------------------+---------------------------------------------+
| Frontend / Widget    | Untrusted          | - Cannot set arbitrary slippage floor       |
|                      |                    | - Floor is cryptographically signed by backend |
+----------------------+--------------------+---------------------------------------------+
| External AMM Pools   | Untrusted          | Authenticated via:                          |
|   - Tinyman v2       |                    |   - On-chain LogicSig hash derivation       |
|   - Pact Standard    |                    |   - Creator pin (PACT_POOL_CREATORS)        |
|   - Pact MWPT        |                    |   - Creator pin + On-chain vault resolution |
|   - STAMM            |                    |   - Creator pin (STAMM_POOL_CREATORS)       |
|   - AlgoFi           |                    |   - Curated whitelist (ALGOFI_POOLS)        |
+----------------------+--------------------+---------------------------------------------+
| Quote Signer Key     | Semi-Trusted       | - Signs slippage floor note only            |
|                      |                    | - Cannot transfer funds or mutate state     |
+----------------------+--------------------+---------------------------------------------+
| Voucher Signer Key   | Semi-Trusted       | - Signs discount percentage only            |
|                      |                    | - Revocable immediately by admin            |
+----------------------+--------------------+---------------------------------------------+
| Admin Key            | Trusted Operator   | - Fee bounded (<= 1.00%)                    |
|                      |                    | - Cannot touch caller in-flight funds       |
|                      |                    | - Conversion pool must be pre-approved      |
+----------------------+--------------------+---------------------------------------------+
```

---

## 2. Threat Analysis & Defensive Mitigations

### T1 — Transaction Group Rekeying / Account Hijacking
- **Threat:** A compromised frontend or malicious caller includes a `rekey_to`, `close_remainder_to`, or `asset_close_to` field in a transaction group to seize account control or drain balances.
- **Mitigation:** `_assert_group_is_clean()` iterates through every outer transaction in the atomic group and asserts that all close and rekey fields equal the zero address.

### T2 — Float Drainage via Opt-In Abuse
- **Threat:** An attacker repeatedly calls `opt_in_asset` with garbage asset IDs to drain the router's 0.1 ALGO MBR per asset.
- **Mitigation:** `opt_in_asset` requires a matching `route` or `route3` call in the same group (`_routed_in_group`), and the route call automatically closes the opened holding and recovers the MBR (`_opened_in_group`).

### T3 — Caller Fund Redirection & Swap Theft
- **Threat:** An attacker tricks the router into sending output funds to an arbitrary third party.
- **Mitigation:** `_pay_out` sends realised swap proceeds strictly to `Txn.sender` (the caller). All inner transaction asset transfers and payments specify `receiver=Txn.sender`.

### T4 — Provider Spoofing (Fake AMM Contracts)
- **Threat:** A caller passes a fake AMM contract application ID that mimics a pool but steals assets deposited into it.
- **Mitigation:**
  - Tinyman v2: Derived on-chain via `_tinyman_v2_pool` hashing.
  - Pact & STAMM: Verified on-chain via `AppParamsGet.app_creator` against immutable creator byte sequences.
  - Pact MWPT: Verified against MWPT factory creator address + dynamic on-chain vault address resolution.
  - AlgoFi: Verified against the static `ALGOFI_POOLS` bytecode array.

### T5 — Treasury Drainage via Conversion Manipulation
- **Threat:** An attacker converts accrued platform fees through an illiquid or malicious pool to drain the treasury.
- **Mitigation:**
  - `convert_and_distribute` is restricted to `Txn.sender == self.admin`.
  - The conversion pool is stored in state (`self.conversion_pool`) and set in a separate group ahead of time (`_assert_no_conversion_pool_approval`).
  - Proceeds are routed exclusively to `self.platform_escrow`.

---

## 3. Operational Runbook & Key Management

### 3.1 Admin Key Operations
- **Custody:** Hardware wallet or multi-signature cold storage.
- **Capabilities:**
  - `set_admin(new_admin)`: Reassign administrative authority.
  - `set_fee(fee_bps)`: Set protocol fee (strictly $\le 100$ bps).
  - `set_escrow(new_escrow)`: Reassign platform fee recipient.
  - `set_quote_signer(new_signer)`: Rotate quote signer public key.
  - `set_voucher_signer(new_signer)`: Rotate or revoke discount voucher key.
  - `set_conversion_pool(leg)`: Pre-approve treasury conversion pool.
  - `convert_and_distribute(...)`: Execute batched treasury conversion.
  - `delete_application()`: Retire contract (only when accrued fees and open holdings are 0).

### 3.2 Quote Signer Key Operations
- **Custody:** Dedicated automated signing server with hardware security module (HSM).
- **Function:** Signs the 80-byte floor note attached to the terminating `pool_budget()` call.
- **Rotation Procedure:** Admin calls `set_quote_signer(new_pubkey)`.

### 3.3 Voucher Signer Key Operations
- **Custody:** Web application backend.
- **Emergency Revocation:** If compromised, admin immediately executes `set_voucher_signer(NO_VOUCHER_SIGNER)`.

---

## 4. Emergency Incident Response Procedures

1. **Compromised Quote Signer:**
   - Execute `set_quote_signer(new_pubkey)`. In-flight quotes with old signatures will fail validation once their `lastValid` round passes.
2. **Compromised Voucher Signer:**
   - Execute `set_voucher_signer(NO_VOUCHER_SIGNER)`.
3. **Malicious External AMM Event:**
   - If an external pool contract experiences an exploit, the router is unaffected because it does not hold inventory in external pools.
   - For treasury conversion, admin sets a safe conversion pool via `set_conversion_pool`.
4. **Contract Retirement:**
   - 1. Convert remaining accrued ALGO via `convert_and_distribute`.
   - 2. Close any lingering dust holdings via `close_holding`.
   - 3. Call `delete_application()` to return remaining float ALGO to admin.
