# [MEDIUM] M6: Same-Group Conversion Pool Approval and Execution

## Location
`contracts/router_app.py:_assert_no_conversion_pool_approval`

## Description
Allowing `set_conversion_pool` and `convert_and_distribute` in the same atomic group would allow an automated script or attacker with compromised credentials to alter the conversion pool dynamically within the spending transaction, bypassing off-chain review and state observation.

## Remediation
Enforced strict separation across atomic groups via `_assert_no_conversion_pool_approval()`:
```python
@subroutine
def _assert_no_conversion_pool_approval(self) -> None:
    selector = arc4.arc4_signature(SET_CONVERSION_POOL_SIGNATURE)
    for index in urange(Global.group_size):
        if gtxn.Transaction(index).type != TransactionType.ApplicationCall:
            continue
        call = gtxn.ApplicationCallTransaction(index)
        if (
            call.app_id == Global.current_application_id
            and call.num_app_args == 2
            and call.app_args(0) == selector
        ):
            assert False, "conversion pool approval must use a separate group"
```

## Status
**Patched and Verified.**
