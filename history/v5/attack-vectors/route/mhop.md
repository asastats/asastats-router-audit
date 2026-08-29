# Attack Vectors: Multi-Hop Execution & Delta Chaining (v5)

## 1. Attack Vector Overview
Multi-hop routing chains the output of hop $i$ directly into the input of hop $i+1$. Inaccurate measurements or reliance on predicted values can cause trades to fail or strand funds.

---

## 2. Specific Vectors & Evaluations

### V-MHOP-01: Predicted vs. Realised Intermediate Stranding
- **Attack:** Leg 2 assumes an off-chain predicted output for Leg 1. If Leg 1 produces slightly less due to price movement, Leg 2 fails to fund and strands intermediate tokens.
- **Evaluation:** The router measures its exact balance before and after Leg 1 (`before = self._held(middle)`, `carried = self._held(middle) - before`) and forwards `carried` directly into Leg 2. Zero funds are stranded.
- **Verdict:** **DEFENDED.**

### V-MHOP-02: Third-Party AMM Log Forgery
- **Attack:** An external pool logs a false return value to manipulate intermediate amount forwarding.
- **Evaluation:** The router never inspects third-party AMM logs or return values. It queries local AVM holding states via `asset_holding_get`.
- **Verdict:** **DEFENDED.**

### V-MHOP-03: Partial Multi-Hop Execution Failure
- **Attack:** Leg 1 succeeds but Leg 2 fails, leaving intermediate funds in the contract.
- **Evaluation:** In Algorand consensus, an atomic group either fully commits or completely rolls back. A failure in Leg 2 aborts the entire group, returning input funds to the user.
- **Verdict:** **DEFENDED.**
