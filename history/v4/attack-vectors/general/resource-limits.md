# Resource Limits Attack Vectors

These vectors analyze attacks that exhaust AVM resources: opcode budget per transaction, group size (max 16 transactions), box storage, and inner transaction count.

The router's defence is to compute the required budget for each route and have the caller add `pool_budget` ApplicationCalls (which are no-ops) to provision extra budget.

## Vectors

### GENERAL-RES-01: Multi-hop route exceeds opcode budget
- **Verdict:** Defended.
- **Code:** The router computes the required budget for each leg (`STAMM_OPCODES_PER_ROUND`, `STABLESWAP_BUDGET_PER_CALL`, etc.) and adds `pool_budget` calls accordingly.
- **Test:** `tests/test_curves_against_chain.py` measures actual opcode usage for real routes.

### GENERAL-RES-02: Group exceeds 16-transaction limit
- **Verdict:** Defended.
- **Code:** The router refuses routes that require more than 16 transactions. Routes with too many legs revert with a clear error.
- **Test:** Manual.

### GENERAL-RES-03: STAMM opups exhausted
- **Verdict:** Defended (M5 v3).
- **Code:** `_swap_leg` asserts `leg.opups.native <= MAX_STAMM_OPUPS`. Non-STAMM legs assert `leg.opups.native == 0`.
- **Test:** `tests/test_stamm_opups.py`.

### GENERAL-RES-04: Box storage exhausted (per-app)
- **Verdict:** Defended.
- **Code:** The router uses no direct box storage. Pools read their own boxes; the router only references pool apps and assets.
- **Test:** n/a.

### GENERAL-RES-05: Inner transaction count limit
- **Verdict:** Defended.
- **Code:** The router limits each route to at most `route3` (3 legs) + opt-ins + payouts + fee pool + quote authentication + verify_discount + pool_budget calls. Total ≤ 16.
- **Test:** Manual.

### GENERAL-RES-06: Fee exhaustion (inner transaction fee = 0)
- **Verdict:** Defended.
- **Code:** All inner transactions have `fee=0`. The outer route call pools its fees via `route_fee` (computed off-chain). The router's ALGO balance is unaffected by inner-txn fees.
- **Test:** Balance neutrality test.

### GENERAL-RES-07: Multiple `pool_budget` calls exceed budget
- **Verdict:** Defended.
- **Code:** `pool_budget` is a no-op ApplicationCall; multiple calls just add to the group's transaction count without consuming budget.
- **Test:** Manual.

### GENERAL-RES-08: STAMM tier-merged leg uses too many opups
- **Verdict:** Defended.
- **Code:** `stamm_routed_leg` (off-chain) merges multiple tiers of the same pool into one `build_swap_routed` leg, avoiding the "transaction already in ledger" collision that two separate opup calls would cause.
- **Test:** Manual.

---

## Detailed analysis

Algorand's opcode budget is 700 per transaction. Each leg of a multi-hop swap may require multiple inner transactions (deposit + pool call), each consuming budget. The router's `pool_budget` mechanism allows the route to add outer no-op ApplicationCalls that the contract can call to provision budget.

The mechanism is:

1. The route declares how many `pool_budget` calls it needs.
2. The caller adds those calls to the group before the route call.
3. Each `pool_budget` call is a no-op (it does nothing but consume a transaction slot).
4. The route call's budget is the group's budget, which includes the `pool_budget` calls' contributions.

This is a common pattern in Algorand multi-hop routers.

The STAMM-specific complication is that STAMM pools require *opup* ApplicationCalls — internal to the pool — that cost budget. The pool itself issues these via inner transactions. The router's `opups` field declares how many opups a leg needs, and the caller must add enough `pool_budget` calls to provision them.

For Pact MWPT pools, the off-chain quoter in `router/legs.py:pact_mwpt_leg` sets `call_sp.fee = 3 * min_fee`, which pays for 3 inner-txn slots (deposit + pool call + something else). The router's `_pact_leg` does not need extra budget provisioning for MWPT legs.

For AlgoFi pools, the leg uses 1 inner transaction (deposit + pool call grouped). The router's `_algofi_leg` does not need extra budget provisioning.

For Tinyman v2, the pool call is a LogicSig (not an application call), so no extra budget is needed.

So only STAMM and Pact stableswap require explicit budget provisioning, and both are handled by the existing `pool_budget` mechanism. MWPT does not require any new mechanism.
