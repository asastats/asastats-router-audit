# Attack Vectors: Group Transactions & Atomicity

## Overview
Algorand executes transactions in atomic groups (up to 16 transactions). In cross-contract routers, attackers frequently attempt to manipulate group composition, transaction ordering, fee pooling, or account authority.

---

### Detailed Attack Vector Analysis

#### AV-GRP-01: RekeyTo Field Hijacking
- **Attack Description:** An attacker or compromised frontend injects a `rekey_to` field into any transaction within the atomic group, rekeying the caller's account to an attacker address during swap authorization.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** `_assert_group_is_clean()` iterates through all transactions in `urange(Global.group_size)` and asserts `transaction.rekey_to == Global.zero_address`. Any non-zero rekey aborts the entire group.

#### AV-GRP-02: CloseRemainderTo / AssetCloseTo Drainage
- **Attack Description:** A malicious transaction in the group specifies a `close_remainder_to` (for ALGO) or `asset_close_to` (for ASAs), draining the signer's entire balance.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** `_assert_group_is_clean()` iterates across all group indices and asserts both `close_remainder_to == Global.zero_address` and `asset_close_to == Global.zero_address`.

#### AV-GRP-03: Non-Adjacent Funding Transaction Smuggling (Finding M2)
- **Attack Description:** An attacker places a funding transfer early in the group (e.g. index 0) and attempts to bind multiple route calls to the same payment, double-spending input funds.
- **Risk Level:** HIGH
- **Verdict:** **Patched**
- **Mechanism:** `_input_amount()` asserts `payment.group_index + 1 == Txn.group_index`. Each route call must be immediately preceded by its distinct funding payment.

#### AV-GRP-04: Group Reordering & Padding
- **Attack Description:** An attacker inserts arbitrary dummy transactions between the route call and the quote authorization note to desynchronize indexing.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** The quote authorization note is strictly pinned to the final transaction in the group (`Global.group_size - 1`), and the per-position input verification reads `Txn.group_index` directly.

#### AV-GRP-05: Group Fee Siphoning / Fee Pooling Exploitation
- **Attack Description:** An attacker includes high-fee transactions in the group hoping the router contract will pool and cover the fees using its own ALGO balance.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** The router sends all inner transactions with `fee = 0`. The router never pays network fees from its balance; all fees must be pooled by the caller's outer transactions.

#### AV-GRP-06: Partial Execution & Revert Atomicity
- **Attack Description:** An external pool reverts on Leg 2, but Leg 1 already completed, stranding intermediate assets in the router.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** Algorand atomic groups ensure all-or-nothing execution. If any inner transaction or assertion in any leg fails, the entire transaction group reverts, restoring all state and balances.
