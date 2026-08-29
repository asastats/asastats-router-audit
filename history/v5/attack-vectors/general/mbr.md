# Attack Vectors: Minimum Balance Requirement (MBR) & Float Solvency (v5)

## 1. Attack Vector Overview
Algorand requires an account to lock 0.1 ALGO MBR for each asset it opts into. A router that holds transient assets could be griefed by attackers creating thousands of opt-ins to drain its operational ALGO.

---

## 2. Specific Vectors & Evaluations

### V-MBR-01: Float Drainage via Unbounded Asset Opt-Ins
- **Attack:** An attacker calls `opt_in_asset` thousands of times with unverified asset IDs to drain the router's ALGO balance.
- **Evaluation:** `opt_in_asset` requires that a route involving that exact asset exists in the same atomic group (`_routed_in_group`). When the route executes, it closes the holding and recovers the 0.1 ALGO in the exact same transaction.
- **Verdict:** **DEFENDED.**

### V-MBR-02: Permanent Box MBR Inflation
- **Attack:** An attacker forces the creation of arbitrary box storage keys to permanently raise the contract's MBR.
- **Evaluation:** The router uses 0 boxes (`box_create` is never called). Global state is fixed at deployment.
- **Verdict:** **DEFENDED.**

### V-MBR-03: Sub-MBR Fee Conversion Trap
- **Attack:** An application holding dust fees less than `MIN_CONVERSION_BATCH` becomes undeletable because it cannot satisfy conversion batch minimums.
- **Evaluation:** The contract permits `batch == self.accrued` when sweeping remaining fees below `MIN_CONVERSION_BATCH`, allowing complete fee evacuation prior to deletion.
- **Verdict:** **DEFENDED.**
