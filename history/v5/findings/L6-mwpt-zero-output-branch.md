# Finding L6: MWPT Zero Output Branch Handling

- **Severity:** Low
- **Category:** AMM Integration / Boundary Handling
- **Location:** `router/curves.py:pact_mwpt_out`
- **Origin:** v4 Audit (2026-08-22)
- **Status (v5):** **VERIFIED SAFE BY DESIGN**

---

## 1. Description
Swapping negligible input amounts through deeply depleted weighted pools could result in 0 output tokens.

---

## 2. Evaluation & Verification
If a leg yields 0 tokens, the router's realised output delta evaluates to 0. This fails the non-zero quote floor check enforced by `_group_paid() >= minimum_received`, causing the entire transaction group to abort cleanly and protect user funds.

---

## 3. Verification Evidence
- `tests/test_pact_mwpt.py` passes.
- Simulation tests confirm zero-output routes fail closed.
