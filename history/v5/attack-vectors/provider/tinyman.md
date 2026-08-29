# Attack Vectors: Tinyman v2 Provider Integration (v5)

## 1. Attack Vector Overview
Tinyman v2 utilizes deterministic stateless logic signature contracts as pool accounts. The pool account holds token reserves and is governed by a central validator application.

---

## 2. Specific Vectors & Evaluations

### V-TINY-01: Fake Tinyman Pool Address Injection
- **Attack:** A caller supplies an arbitrary account address mimicking a Tinyman v2 pool to receive user swap deposits.
- **Evaluation:** The router does not accept a pool address argument. `_tinyman_v2_pool` reconstructs the 47-byte logic signature bytecode on-chain using the validator template and the two asset IDs, computing the exact SHA-512/256 program hash. Deposits are dispatched exclusively to this derived address.
- **Verdict:** **DEFENDED.**

### V-TINY-02: Tinyman v1 Incompatible Dispatch
- **Attack:** A route attempts to swap through Tinyman v1.1.
- **Evaluation:** Tinyman v1.1 requires the outer sender to match the input funder, which is incompatible with inner transaction dispatch. Tinyman v1 is excluded by design; attempting to dispatch to a v1 pool is rejected on-chain.
- **Verdict:** **DEFENDED.**

### V-TINY-03: Validator Application Spoofing
- **Attack:** A caller points the swap call at a malicious validator application.
- **Evaluation:** The Tinyman v2 validator application ID is hardcoded via the compile-time template variable `TINYMAN_V2_APP_ID` (App ID `1002541853` on mainnet). Callers cannot override it.
- **Verdict:** **DEFENDED.**
