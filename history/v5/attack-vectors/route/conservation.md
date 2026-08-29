# Attack Vectors: Value Conservation & Pre-Held Asset Protection (v5)

## 1. Attack Vector Overview
Aggregators must ensure that 100% of deposited user funds are accounted for, converted, or refunded, without leaving leftover balances in the contract.

---

## 2. Specific Vectors & Evaluations

### V-CONS-01: Pre-Held Asset Input Stranding
- **Attack:** If the router already holds a non-zero balance of Asset $X$, an external pool in Leg 1 only consumes part of the user's input $A_{\text{in}}$, leaving the remainder stranded in the router.
- **Evaluation:** `_assert_input_spent(asset_in, input_before, amount_in)` records the holding prior to swap dispatch and explicitly asserts `self._held(asset_in) == input_before - amount_in`. If any part of the input remains unspent, the transaction reverts immediately.
- **Verdict:** **DEFENDED.**

### V-CONS-02: Intermediate Dust Accumulation
- **Attack:** Rounding micro-fractions accumulate across thousands of swaps, creating a target for balance sweeps.
- **Evaluation:** Temporary intermediate holdings are opened and closed within the swap transaction group, returning all funds or closing to the creator.
- **Verdict:** **DEFENDED.**

### V-CONS-03: Cross-User Balance Contamination
- **Attack:** User B's swap output is subsidized by unclosed dust left by User A.
- **Evaluation:** Delta-based measurement ensures that each swap's output is calculated strictly as `held_after - held_before`, isolating trades from pre-existing balances.
- **Verdict:** **DEFENDED.**
