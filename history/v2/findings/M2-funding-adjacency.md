# M2 — Funding transaction was not adjacent to the route call

**Severity:** Medium
**Status:** Patched in the worktree

`_input_amount` previously accepted a transaction reference from anywhere in
the group. The off-chain builder assumed the immediate predecessor shape, but
the contract did not enforce it. This made group accounting depend on an
off-chain convention and permitted malformed groups to reuse a funding
reference.

The contract now requires `payment.group_index + 1 == Txn.group_index`.
