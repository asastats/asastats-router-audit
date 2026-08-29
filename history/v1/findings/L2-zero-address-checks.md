# L2 — `set_admin` and `set_escrow` do not reject the zero address

**Severity:** Low  
**Location:** `router/contracts/router_app.py`, `set_admin` / `set_escrow`  
**Status:** **Patched**

> `set_admin` and `set_escrow` both assert the account is not the zero address.
> `set_quote_signer` does the same, for a stronger reason — see H1: a floor must
> fail closed, so its signer may be rotated but never revoked.

## Description

Neither `set_admin` nor `set_escrow` asserts that the supplied account is not the zero address. Setting the admin to the zero address would brick all admin functions; setting the escrow to zero would cause `convert_and_distribute` to fail when paying out ASASTATS.

## Impact

- Accidental loss of admin control.
- Failed fee distributions.

## Recommended fix

```python
assert admin != Global.zero_address, "admin cannot be zero"
assert escrow != Global.zero_address, "escrow cannot be zero"
```

This is a cheap defence-in-depth check.
