# Attack Vectors: Inner Transactions & Subroutine Calls

## Overview
The smart router interacts with external AMM pools and returns output funds using AVM inner transactions (`itxn`). These must be strictly constructed to avoid fee draining, receiver misdirection, or reentrancy.

---

### Detailed Attack Vector Analysis

#### AV-INN-01: Inner Transaction Fee Draining
- **Attack Description:** Inner transactions issued by the router specify non-zero fees, draining the router's ALGO operational float over repeated swaps.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** Every inner transaction across the entire contract (`Payment`, `AssetTransfer`, `ApplicationCall`) explicitly sets `fee = 0`. Outer transactions pool the fee.

#### AV-INN-02: Payout Receiver Misdirection
- **Attack Description:** An attacker manipulates method parameters so that the final output asset is sent to an address other than the transaction sender.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** In `route` and `route3`, payout is hardcoded to `Txn.sender`:
  `self._pay_out(Txn.sender, asset_out, received, opened)`. No recipient address parameter is accepted from the caller.

#### AV-INN-03: Inner Call Reentrancy via External Pools
- **Attack Description:** An external pool contract called via inner transaction calls back into the router within the same execution context to mutate state or steal funds.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** The router does not rely on intermediate mutable state variables for accounting; all accounting uses local variables and immediate balance delta checks. Furthermore, the AVM prevents direct application recursive calls.

#### AV-INN-04: Intermediate Asset Custody Leakage
- **Attack Description:** An inner transaction leaves intermediate ASA balances in the router without closing the holding, accumulating dust or blocking future swaps.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** Intermediate holdings opened for the swap are checked for zero balance (`assert self._held(middle) == 0`) and closed immediately via `AssetTransfer(asset_close_to=Txn.sender, fee=0)`.
