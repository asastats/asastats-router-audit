# L3 — No explicit reentrancy-style phase guard

**Severity:** Low  
**Location:** `router/contracts/router_app.py`, `route` / `route3`  
**Status:** Accepted / documented

## Description

Analysis3 recommends an execution-phase guard (`locked` global state) to prevent a malicious external pool from calling back into the router in the same group.

On Algorand, the AVM already rejects an inner application call that re-enters an application currently on the call stack. A pool cannot directly call back into the router while the router is calling it.

## Impact

- The standard EVM-style reentrancy attack is not possible.
- A more subtle cross-app state manipulation via grouped transactions is theoretically possible but not identified in this audit.

## Recommended fix

No source change is strictly required. Consider adding a `locked` flag if the contract is later composed with untrusted applications in more complex ways.
