# [MEDIUM] M2: Non-Adjacent Funding Transaction Smuggling

## Location
`contracts/router_app.py:_input_amount`

## Description
When funding transactions are referenced purely by an index without relative positioning enforcement, an attacker could attempt to point multiple route calls to the same single funding payment, or separate the funding payment from the route call in complex atomic groups.

## Remediation
Enforced strict relative adjacency in `_input_amount`:
```python
assert payment.sender == Txn.sender, "input must come from the caller"
assert payment.group_index + 1 == Txn.group_index, (
    "input must immediately precede the route"
)
```

## Status
**Patched and Verified.**
