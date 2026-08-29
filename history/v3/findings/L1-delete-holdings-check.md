# [LOW] L1: Explicit Asset Holding Check on Application Deletion

## Location
`contracts/router_app.py:delete_application`

## Description
In Algorand, an application account cannot be closed out if it still holds any opted-in ASA balances. Without an explicit check in the contract, a delete transaction would fail with an opaque AVM error rather than a clear assertion message.

## Remediation
Added explicit holding check:
```python
assert Global.current_application_address.total_assets == 0, (
    "an asset is still held; close it first"
)
```

## Status
**Patched and Verified.**
