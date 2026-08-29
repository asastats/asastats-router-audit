# Attack Vectors: Pact Standard & Stableswap Provider Integration (v5)

## 1. Attack Vector Overview
Pact constant-product and stableswap pools are stateful smart contracts whose accounts act as pool escrows.

---

## 2. Specific Vectors & Evaluations

### V-PACT-01: Fake Pact Pool Application Injection
- **Attack:** A caller passes an application ID of an attacker-deployed contract that mimics Pact's `SWAP` selector.
- **Evaluation:** `_pact_leg` invokes `_assert_created_by(leg.app.as_uint64(), TemplateVar[Bytes]("PACT_POOL_CREATORS"))`. The contract queries `AppParamsGet.app_creator` and verifies the creator matches one of the pinned official Pact factory addresses.
- **Verdict:** **DEFENDED.**

### V-PACT-02: Asset Reference Array Misalignment
- **Attack:** A caller reverses the order of assets in the transaction reference array to trick Pact's positional checks.
- **Evaluation:** `_pact_leg` orders the asset references strictly according to the pool's natural configuration (`leg.asset_a`, `leg.asset_b`), satisfying Pact's positional assertions.
- **Verdict:** **DEFENDED.**

### V-PACT-03: Stableswap Invariant Precision Drift
- **Attack:** Large swaps through Pact stableswap pools cause numerical instability or division by zero in off-chain curves.
- **Evaluation:** The off-chain curve (`router/curves.py`) implements full Newton-Raphson iteration identical to Pact SDK, verified across test suites to within $\pm 0$ units.
- **Verdict:** **DEFENDED.**
