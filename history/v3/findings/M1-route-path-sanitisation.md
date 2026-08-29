# [MEDIUM] M1: Unsanitized Route Paths (Cycles and Duplicate Assets)

## Location
`contracts/router_app.py:route`, `contracts/router_app.py:route3`

## Description
Without on-chain path validation, callers could submit circular routes (e.g., A -> B -> A) or self-intersecting paths (e.g., A -> B -> B -> C), resulting in wasted fees, distorted intermediate state, or potential accounting griefing.

## Remediation
Added explicit distinctness assertions in `route` and `route3`:
```python
# In route:
assert asset_in != asset_out, "a route must change the asset"
assert middle != asset_in, "route visits the same asset twice"
assert middle != asset_out, "route visits the same asset twice"

# In route3:
assert asset_in != asset_out, "a route must change the asset"
assert first_middle != asset_in, "route visits the same asset twice"
assert first_middle != asset_out, "route visits the same asset twice"
assert second_middle != asset_in, "route visits the same asset twice"
assert second_middle != asset_out, "route visits the same asset twice"
assert first_middle != second_middle, "a route cannot cross itself"
```

## Status
**Patched and Verified.**
