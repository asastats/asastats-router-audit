# M2 — No quote deadline / stale-group execution

**Severity:** Medium  
**Location:** `router/contracts/router_app.py`, `route` / `route3`  
**Status:** **Patched** — structurally, with no parameter and no ABI change of its own

> **Resolved by the H1 fix rather than by a `deadline_round` argument.** Every
> routed group must now carry the quote signer's co-signed transaction, and that
> transaction has its own `lastValid` round. A group is atomic, so it cannot
> commit after its authorisation expires — the network enforces the deadline and
> the contract needs no argument and no `Global.round` comparison. The quote's
> lifetime becomes something the backend sets when it signs, which is where
> quote validity is decided anyway.
>
> The consequence an auditor should check rather than assume: this makes quoting
> *mandatory* before executing, because a group cannot be built from an
> authorisation that has expired.

## Description

`route` and `route3` accept `minimum_received` but no deadline. A group built from a quote can be submitted at any later round, as long as the output floor is still met.

This is not a direct fund-loss bug, but it is a standard DeFi safety parameter that is missing. A stale quote may execute in market conditions the user did not approve.

## Impact

- Users may have trades execute long after they clicked approve.
- Off-chain quotes have an implicit expiry, but it is not enforced by the contract.

## Recommended fix

Add a `deadline_round` parameter to the next deployment's `route`/`route3` methods:

```python
assert Global.round <= deadline_round, "quote expired"
```

This is an ABI change and should be introduced together with the signed-floor work so that only one redeployment is needed.
