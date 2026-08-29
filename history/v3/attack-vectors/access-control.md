# Attack Vectors: Access Control & Privileged Operations

## Overview
Privileged functions control protocol parameters, treasury conversions, and administrative keys. Access control must prevent unauthorized modification or privilege escalation.

---

### Detailed Attack Vector Analysis

#### AV-ACC-01: Unauthorized Reassignment of Admin
- **Attack Description:** A non-admin caller attempts to call `set_admin` to take ownership of the contract.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** `assert Txn.sender == self.admin, "only the admin may reassign"` on `set_admin`.

#### AV-ACC-02: Zero-Address Admin / Escrow Assignment (Finding L2)
- **Attack Description:** Admin sets `admin` or `platform_escrow` to the zero address (`Global.zero_address`), permanently locking administrative control or stranding fees.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** `set_admin` asserts `admin != Global.zero_address`. `set_escrow` asserts `escrow != Global.zero_address` and verifies `FEE_ASSET_ID` opt-in.

#### AV-ACC-03: Excessive Fee Rate Exploitation
- **Attack Description:** A compromised admin key sets `fee_bps` to 100% (10,000 bps) to drain user trades.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** `set_fee` enforces `assert fee_bps <= MAX_FEE_BPS` where `MAX_FEE_BPS = 100` (1.0% hard cap).

#### AV-ACC-04: Quote Signer Revocation to Bypass Slippage
- **Attack Description:** An attacker or malicious admin sets `quote_signer` to zero to force the contract to accept unverified user floors.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** `set_quote_signer` asserts `signer != Global.zero_address`. The quote signer can be rotated but never revoked.

#### AV-ACC-05: Unauthorized Application Deletion
- **Attack Description:** A non-admin caller invokes `delete_application` to destroy the router and steal funds.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** `delete_application` enforces `assert Txn.sender == self.admin`, `assert self.accrued == 0`, and `assert Global.current_application_address.total_assets == 0`.
