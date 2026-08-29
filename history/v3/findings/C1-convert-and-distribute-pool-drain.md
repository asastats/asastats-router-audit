# [CRITICAL] C1: Permissionless Fee Conversion Drains Accrued Platform Fees

## Location
`contracts/router_app.py:convert_and_distribute`

## Description
In earlier revisions, `convert_and_distribute` was permissionless and accepted a `Leg` struct directly from the caller naming the pool through which accrued ALGO fees would be converted into `ASASTATS`.

## Attack Scenario
1. The router accumulates accrued fees in `self.accrued`.
2. An attacker calls `convert_and_distribute`, supplying their own attacker-controlled application as `leg.app`.
3. The router deposits `self.accrued` ALGO into the attacker's application.
4. The attacker's application returns zero `ASASTATS`.
5. The attacker passes `minimum_out = 0`.
6. The transaction succeeds, `self.accrued` is decremented to 0, and all platform revenue is stolen.

## Remediation
1. Restricted `convert_and_distribute` strictly to `self.admin`:
   ```python
   assert Txn.sender == self.admin, "only the admin may convert"
   ```
2. Removed the `Leg` argument from `convert_and_distribute`. The pool is now pre-approved in global state via `set_conversion_pool`.
3. Enforced `minimum_out > 0` and bounded the conversion batch between `MIN_CONVERSION_BATCH` and `MAX_CONVERSION_BATCH`.

## Status
**Patched and Verified** in unit and LocalNet test suites.
