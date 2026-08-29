# Attack Vectors: Conversion & Platform Treasury

## Overview
The router accumulates platform revenue in ALGO from trades through ALGO intermediates. Periodically, `convert_and_distribute` swaps accrued ALGO into `ASASTATS` and distributes it to the platform escrow.

---

### Detailed Attack Vector Analysis

#### AV-TRZ-01: Public Conversion Pool Drain (Finding C1)
- **Attack Description:** In v1, `convert_and_distribute` was permissionless and accepted an arbitrary caller-supplied pool, allowing an attacker to drain all accrued fees into their own pool.
- **Risk Level:** CRITICAL
- **Verdict:** **Patched**
- **Mechanism:** `convert_and_distribute` is restricted to `self.admin` (`assert Txn.sender == self.admin`) and reads the pool from pre-approved global state (`self.conversion_pool`).

#### AV-TRZ-02: Same-Group Pool Approval & Conversion (Finding M6)
- **Attack Description:** An attacker or rogue script bundles `set_conversion_pool` and `convert_and_distribute` into the same atomic transaction group to bypass operational review.
- **Risk Level:** HIGH
- **Verdict:** **Patched**
- **Mechanism:** `_assert_no_conversion_pool_approval()` scans the group and asserts that `set_conversion_pool` is NOT present in the same group.

#### AV-TRZ-03: Zero-Floor Conversion Drain (Finding L4 / M1 v2)
- **Attack Description:** Admin converts accrued fees with `minimum_out = 0`, allowing sandwich attackers to steal treasury funds.
- **Risk Level:** MEDIUM
- **Verdict:** **Patched**
- **Mechanism:** `convert_and_distribute` enforces `minimum_out > 0`, unless the batch is a sub-floor dust sweep (`batch == self.accrued and batch < MIN_CONVERSION_BATCH`).

#### AV-TRZ-04: Batch Ceiling Bypass
- **Attack Description:** Converting an excessively large ALGO batch in a single call, moving the market against the treasury.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** Enforces `assert batch <= MAX_CONVERSION_BATCH` (500 ALGO hard ceiling).
