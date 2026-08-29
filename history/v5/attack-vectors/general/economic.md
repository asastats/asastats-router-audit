# Attack Vectors: Economic Exploitation & Fee Accounting (v5)

## 1. Attack Vector Overview
Economic attack surfaces include fee skimming manipulation, forged discount vouchers, treasury drain, and sandwich / MEV extraction.

---

## 2. Specific Vectors & Evaluations

### V-ECON-01: Excessive Platform Fee Extraction
- **Attack:** A compromised admin key sets an exorbitant fee rate (e.g., 99%) to drain user swaps.
- **Evaluation:** `set_fee` enforces `assert fee_bps <= MAX_FEE_BPS` (hardcoded ceiling of 100 bps / 1.00%). Even a compromised admin cannot set a fee exceeding 1%.
- **Verdict:** **DEFENDED.**

### V-ECON-02: Forged Fee Discount Vouchers
- **Attack:** An attacker crafts a counterfeit voucher claiming a 100% fee discount.
- **Evaluation:** `verify_discount` validates a 64-byte Ed25519 cryptographic signature against `self.voucher_signer` over a domain-separated payload binding `(app_id, sender, expiry, discount)`. Invalid signatures fail immediately.
- **Verdict:** **DEFENDED.**

### V-ECON-03: Multiple Fee Skimming on Multi-Leg Routes
- **Attack:** A 3-leg route with multiple ALGO intermediates is charged fees repeatedly.
- **Evaluation:** In `route3`, the fee skim executes at most once on whichever intermediate is ALGO, preventing duplicate fee assessments.
- **Verdict:** **DEFENDED.**

### V-ECON-04: Treasury Drainage via Permissionless Conversion
- **Attack:** An attacker converts accrued fees through a malicious pool to steal treasury ALGO.
- **Evaluation:** `convert_and_distribute` is restricted to `Txn.sender == self.admin`, uses a pre-approved conversion pool from global state, and sends all output to `self.platform_escrow`.
- **Verdict:** **DEFENDED.**
