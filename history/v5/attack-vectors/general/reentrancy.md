# Attack Vectors: Reentrancy & Cross-Call State Manipulation (v5)

## 1. Attack Vector Overview
In the Algorand Virtual Machine (AVM), classical EVM-style call-stack reentrancy is structurally prevented because contract calls run synchronously to completion without arbitrary external callback hooks during an opcode. However, aggregator contracts face **cross-transaction group reentrancy-analogue vulnerabilities**, where external contracts called within an atomic group attempt to interact with the router in subsequent group slots or manipulate shared state.

---

## 2. Specific Vectors & Evaluations

### V-REEN-01: Re-entry via Subsequent Group Transactions
- **Attack:** An external malicious pool called in leg 1 issues an inner transaction or coordinates with a subsequent outer transaction to call back into `route` / `convert_and_distribute` mid-execution.
- **Evaluation:** The router maintains zero mutable state across swap hops within a single call. Swap inputs are consumed immediately and outputs are measured by local balance deltas. The caller funding payment must immediately precede the route call (`payment.group_index + 1 == Txn.group_index`). A second call would require its own funding payment.
- **Verdict:** **DEFENDED.**

### V-REEN-02: State Desynchronization via Shared External Pool State
- **Attack:** An external pool manipulates global variables or temporary reserves to trick the router's accounting.
- **Evaluation:** The router never queries external pool state or reported swap outcomes to determine input amounts or outputs. It relies strictly on `_held(asset_out) - before` on its own account.
- **Verdict:** **DEFENDED.**

### V-REEN-03: Transient Storage Contamination
- **Attack:** State flags set during a failed swap remain active for a subsequent swap in the same group.
- **Evaluation:** Algorand atomic groups fail completely if any transaction aborts; no partial state persists. If a group completes, all opened holdings are closed in the same execution.
- **Verdict:** **DEFENDED.**
