# [LOW] L5: Voucher Signer Key Separation and Rotation

## Location
`contracts/router_app.py:set_voucher_signer`, `verify_discount`

## Description
The voucher signing key authorizes fee discounts (0–100%) and resides on a web backend. If compromised, the attacker can mint free trades, but cannot steal funds or alter governance.

## Evaluation & Status
The voucher signing key is strictly isolated from the admin key. Compromise of the voucher key only allows discount fee waivers (bounded to platform revenue). The admin can instantly revoke the key by setting it to `NO_VOUCHER_SIGNER` (`bytes(32)`).

## Status
**Documented and Accepted by Design.**
