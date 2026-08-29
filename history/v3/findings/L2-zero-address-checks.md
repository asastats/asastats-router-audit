# [LOW] L2: Zero-Address Validation on Critical Setters

## Location
`contracts/router_app.py:set_admin`, `set_escrow`, `set_quote_signer`

## Description
Accidentally setting administrative roles, escrow accounts, or quote signers to the zero address (`Global.zero_address`) could permanently lock governance, burn platform revenue, or disable slippage protection.

## Remediation
Added explicit assertions against `Global.zero_address`:
```python
assert admin != Global.zero_address, "admin cannot be the zero address"
assert escrow != Global.zero_address, "escrow cannot be the zero address"
assert signer != Global.zero_address, "the quote signer cannot be unset"
```

## Status
**Patched and Verified.**
