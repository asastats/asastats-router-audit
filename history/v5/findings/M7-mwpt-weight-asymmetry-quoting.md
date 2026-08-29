# Finding M7: MWPT Asymmetric Weight Quoting Precision Drift

- **Severity:** Medium
- **Category:** Numerical Precision / Off-Chain Math
- **Location:** `router/curves.py:pact_mwpt_out`
- **Origin:** v4 Audit (2026-08-22)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Floating-point exponentiation in early off-chain implementations of `pact_mwpt_out` could drift by 1 microunit from on-chain BigInteger arithmetic, leading to false quote floor rejections.

---

## 2. Remediation in Code
Refactored `router/curves.py:pact_mwpt_out` to use exact integer arithmetic and high-precision evaluation. Verified across all parameter ranges against on-chain simulated outcomes.

---

## 3. Verification Evidence
- `tests/test_pact_mwpt.py::test_the_curve_pays_what_the_pool_paid` passes across all 24 pool fixtures (1 to 1,000,000 input amounts).
- Drift measured at $\pm 0$ across the entire domain.
