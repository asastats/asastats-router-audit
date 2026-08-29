# Architectural Comparison: STAMM AMM Pool vs. Smart Router (v5)

Understanding the fundamental difference in threat models between a self-contained AMM pool (STAMM) and a cross-protocol aggregator (Smart Router) is vital to conducting a rigorous audit.

---

## 1. Core Architectural Differences

```
+-----------------------------------------------------------------------------------------+
|                        STAMM AMM POOL vs. SMART ROUTER MATRIX                           |
+--------------------------+------------------------------+-------------------------------+
| Dimension                | STAMM AMM Pool               | ASA Stats Smart Router        |
+--------------------------+------------------------------+-------------------------------+
| Role                     | Liquidity host & AMM pool    | Cross-protocol aggregator     |
| TVL / Inventory          | Long-term permanent deposits | Zero inventory (transient)    |
| External Calls           | Self-contained (mostly inner)| High (calls 4+ external AMMs) |
| Mathematical Invariant   | Multi-tier Constant-Product  | Conservation of value ($\Delta B$) |
| Slippage Enforcement     | Per-pool $x \cdot y \ge k$   | Backend co-signed group note  |
| Asset Storage            | Long-term opted-in assets    | Same-group open/close cycle   |
| Primary Vulnerability    | K-invariant manipulation     | Provider spoofing / routing   |
+--------------------------+------------------------------+-------------------------------+
```

---

## 2. Shift in Security Focus

### STAMM Focus: "Is our internal mathematical model sound?"
- Verifies 128-bit fixed-point arithmetic.
- Proves $K$-invariant growth across multi-tier liquidity strata.
- Analyzes LP token mint/burn lifecycle and fee spill distribution.
- Audits local box storage and registry synchronization.

### Smart Router Focus: "What if external contracts lie or misbehave?"
- Aggregates untrusted third-party pools (Tinyman, Pact, STAMM, AlgoFi).
- Guards against fake pool applications via cryptographic derivation and creator pinning.
- Measures realised outputs strictly via local holding deltas rather than pool-reported return values.
- Guarantees zero residual balance contamination across users.
- Enforces strict atomicity and whole-group cleanliness (rekey/close protection).
