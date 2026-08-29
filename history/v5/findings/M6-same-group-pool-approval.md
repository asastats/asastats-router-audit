# Finding M6: Same-Group Conversion Pool Approval & Execution

- **Severity:** Medium
- **Category:** Treasury Governance / Atomicity
- **Location:** `contracts/router_app.py:_assert_no_conversion_pool_approval`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Allowing `set_conversion_pool` and `convert_and_distribute` within the same atomic transaction group would allow atomic pool substitution during treasury spending, circumventing separate inspection.

---

## 2. Remediation in Code
Implemented subroutine `_assert_no_conversion_pool_approval`:
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
Invoked at the beginning of `convert_and_distribute`.

---

## 3. Verification Evidence
- `TestTheApprovedConversionPool` tests pass.
- LocalNet test confirming atomic group rejection on same-group setter execution.
