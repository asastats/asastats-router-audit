# Reentrancy Attack Vectors

Algorand does not have EVM-style reentrancy, but a router that issues inner transactions to external pools can still be vulnerable to "reentrancy-analogue" attacks if:

- A pool issues a sub-call that re-enters the router.
- A pool manipulates shared state via grouped transactions.
- A pool calls back into the router in a way that breaks the router's assumptions.

The router's defence is that it operates on a local frame (no cross-call state) and that every state transition is enclosed within a single `@arc4.abimethod`.

## Vectors

### GENERAL-REENT-01: Pool calls back into router mid-swap
- **Verdict:** Defended.
- **Code:** The router's entry points are gated by `Txn.sender == Global.current_application_id` checks in the dispatch logic; a pool calling the router would be a separate ApplicationCall, which the router's invariants do not depend on. Balance is measured by `_held(asset_out) - before`, which reflects the cumulative state at the end of the inner txn.
- **Test:** Manual adversarial pool test.

### GENERAL-REENT-02: Pool reuses same asset pair for nested call
- **Verdict:** Defended.
- **Code:** Atomic groups mean all inner transactions are evaluated as a single batch; nested calls are not possible.
- **Test:** n/a.

### GENERAL-REENT-03: Pool triggers sub-call that closes its own address
- **Verdict:** Not applicable.
- **Code:** A pool closing its own address would prevent it from being called; subsequent swaps to that pool fail.
- **Test:** Manual.

### GENERAL-REENT-04: Pool mutates global state mid-swap
- **Verdict:** Defended.
- **Code:** Atomic groups mean global state changes are visible only after the group settles; intermediate state is consistent.
- **Test:** n/a.

### GENERAL-REENT-05: Two pools in same group share an asset and balance
- **Verdict:** Defended.
- **Code:** The router's balance measurement reflects the cumulative effect of all inner transactions in the group, not the per-pool state.
- **Test:** Adversarial pool test.

### GENERAL-REENT-06: Quote signer's transaction is a re-entrant ApplicationCall
- **Verdict:** Defended (I2 v3).
- **Code:** `_signed_floor` asserts `TransactionType.ApplicationCall` and that the transaction has exactly one application arg matching `POOL_BUDGET_SIGNATURE`. A re-entrant call would have a different signature and be rejected.
- **Test:** Manual.

### GENERAL-REENT-07: Reentrancy via verify_discount in same group
- **Verdict:** L3 (accepted by design).
- **Code:** `verify_discount` is a separate ApplicationCall in the group. It does not modify router state (it only verifies a signature). The discount is read by the route call via the same group's atomicity.
- **Note:** This is a documented accepted risk in v3 finding L3. The audit confirms it remains by design.
- **Test:** Manual.

---

## Detailed analysis

Algorand's atomic-group semantics are *not* equivalent to EVM's reentrancy. In an EVM contract, a call to an external contract can execute arbitrary code that re-enters the original contract before the original call returns. In Algorand:

- A transaction group is committed atomically; either all transactions settle or none do.
- Inner transactions are part of the same atomic group; their effects are visible to subsequent inner transactions in the group.
- An inner transaction cannot call the *parent* application in a way that affects the parent's invariants mid-execution, because the parent's invariants are checked at the end of the parent's entry point.

So reentrancy-style attacks on Algorand are structurally different. The "reentrancy analogue" is:

- A pool that takes the user's input, executes an inner call back into the router (e.g., to read the router's state), and then either returns or fails. The router's state at the time of the inner call is the state *after* the pool's deposit but *before* the pool's payout. If the router exposes any state that the pool can read and use to its advantage, the router must guard against this.

In the current router:

- The router's `accrued` field is *not* exposed to the pool.
- The router's quote-signer authentication is *not* exposed to the pool.
- The router's admin/escrow/conversion-pool fields are *not* exposed to the pool.

The router does expose its own ALGO balance (via `_held(0)`) to the pool, but the pool can read this only via a re-entrant call to the router, which would require the pool to construct a valid ApplicationCall that the router accepts. The router's dispatch logic checks `Txn.sender`, but `Txn.sender` for an inner transaction is the router itself (since the router is the originator). So a pool cannot impersonate an external user calling the router.

The one residual risk is `verify_discount` — it is an ApplicationCall in the same group, and the pool could conceivably mimic it. But the signature scheme uses `Ed25519` with a specific 96-byte message, so a pool cannot forge it.

Conclusion: reentrancy-analogue is not exploitable in the current router. The L3 finding remains "accepted by design" because the local-frame accounting approach is structurally sound, but no on-chain invariant *asserts* it.
