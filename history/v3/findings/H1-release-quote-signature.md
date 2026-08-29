# [HIGH] H1: Frontend-Controlled Floor Allows Predatory Execution (T5 Residual)

## Location
`contracts/router_app.py:route`, `contracts/router_app.py:route3`, `_signed_floor`

## Description
Previously, `minimum_received` was passed as an explicit parameter to `route` and `route3`. If a frontend widget was compromised (via supply-chain attack or XSS), the attacker could set `minimum_received = 0` and route user trades through adversarial or skewed pools, extracting nearly 100% of the trade value.

## Remediation
1. Removed `minimum_received` from the ABI parameters of `route` and `route3`.
2. Implemented `_signed_floor()` using an atomic co-signed transaction sent by `self.quote_signer`.
3. The floor note authenticates:
   - Application ID
   - Caller account (`Txn.sender`)
   - Output asset ID
   - Input amount per route position
   - Asserting route index
4. `set_quote_signer` rejects the zero address, ensuring the floor check fails closed.

## Status
**Patched and Verified.**
