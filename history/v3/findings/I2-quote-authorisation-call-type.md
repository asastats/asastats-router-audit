# [INFORMATIONAL] I2: Explicit Transaction Type Pinning on Quote Authorization Call

## Location
`contracts/router_app.py:_signed_floor`

## Description
The quote authorization transaction at the end of the group was previously evaluated without explicitly pinning its transaction type before accessing application call fields.

## Remediation
Added explicit validation:
```python
assert authorisation.type == TransactionType.ApplicationCall, (
    "the quote authorisation is not an application call"
)
quote_call = gtxn.ApplicationCallTransaction(Global.group_size - 1)
assert quote_call.app_id == Global.current_application_id
assert quote_call.num_app_args == 1
assert quote_call.app_args(0) == arc4.arc4_signature(POOL_BUDGET_SIGNATURE)
```

## Status
**Patched and Verified.**
