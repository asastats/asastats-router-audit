# L5 — Voucher signer key has no rotation timelock

**Severity:** Low  
**Location:** `router/contracts/router_app.py`, `set_voucher_signer`  
**Status:** Documented

## Description

`set_voucher_signer` can be called instantly by the admin. Compromise of the admin key (or a buggy admin call) can rotate the voucher signer and invalidate all in-flight vouchers.

## Impact

- Discounts can be revoked instantly.
- An attacker with the admin key can mint full-fee waivers for themselves.

## Recommended fix

The threat model already treats voucher-signer compromise as bounded to platform revenue and recoverable by a single admin transaction. If stronger guarantees are desired, consider:

- A two-step rotation with a delay, or
- A separate, lower-privilege key that can only rotate the voucher signer.

No source change is required unless the project wants stronger governance.
