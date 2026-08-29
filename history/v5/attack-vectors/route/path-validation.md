# Attack Vectors: Path Validation & Route Sanitization (v5)

## 1. Attack Vector Overview
Invalid or cyclic route paths can result in fee loops, self-transfers, or accounting confusion.

---

## 2. Specific Vectors & Evaluations

### V-PATH-01: Circular Routing (A → B → A)
- **Attack:** An attacker passes identical input and output assets (`asset_in == asset_out`) or a circular intermediate (`asset_in == middle`), generating fee bleed.
- **Evaluation:**
  - `route` asserts `asset_in != middle and middle != asset_out and asset_in != asset_out`.
  - `route3` asserts pairwise distinctness across all 4 asset positions: `asset_in`, `first_middle`, `second_middle`, and `asset_out`.
- **Verdict:** **DEFENDED.**

### V-PATH-02: Crossed Intermediates in 3-Leg Swaps
- **Attack:** An attacker supplies `first_middle == second_middle` in `route3`.
- **Evaluation:** `route3` explicitly asserts `first_middle != second_middle, "a route cannot cross itself"`.
- **Verdict:** **DEFENDED.**

### V-PATH-03: Zero Asset ID Ambiguity (ALGO vs. ASA 0)
- **Attack:** A route confuses ALGO (Asset ID 0) with a valid ASA.
- **Evaluation:** The contract explicitly branches on `asset == 0` for all native payment versus asset transfer operations.
- **Verdict:** **DEFENDED.**
