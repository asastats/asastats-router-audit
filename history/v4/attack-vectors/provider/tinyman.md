# Tinyman v2 Attack Vectors

Tinyman v2 pools use LogicSig accounts (not application calls). The router derives the pool's address on-chain via `sha512_256` of the template LogicSig + assets + fee_bps + other parameters.

## Vectors

### TINYMAN-01: Caller-supplied pool address
- **Verdict:** Defended (M4 v3, M3 v1).
- **Code:** Pool address is derived on-chain, not supplied by caller.
- **Test:** `tests/test_router_contract.py::test_tinyman_pool_address_derived`.

### TINYMAN-02: LogicSig template upgrade
- **Verdict:** Defended (M6 v1).
- **Code:** The on-chain derivation uses the template's current logic. If Tinyman upgrades their template, the new address is derived; the old pool is no longer routable.
- **Test:** Manual.

### TINYMAN-03: Wrong assets in pool derivation
- **Verdict:** Defended.
- **Code:** The derivation uses the route's `asset_a`, `asset_b`. If they don't match the actual pool, the derived address is wrong, and the deposit goes to a non-existent account (route reverts).
- **Test:** Manual.

### TINYMAN-04: Wrong fee_bps in pool derivation
- **Verdict:** Defended.
- **Code:** Fee is part of the derivation. Mismatch leads to wrong address.
- **Test:** Manual.

### TINYMAN-05: Tinyman pool with single asset (invalid)
- **Verdict:** Defended.
- **Code:** The derivation requires both assets; single-asset pool would have invalid derivation.
- **Test:** Manual.

### TINYMAN-06: Tinyman pool with extreme reserves
- **Verdict:** Defended.
- **Code:** The router measures output by balance delta, not by formula. Extreme reserves don't break the measurement.
- **Test:** Manual.

### TINYMAN-07: Tinyman v1 pool (deprecated)
- **Verdict:** Defended.
- **Code:** The router only supports Tinyman v2. V1 pools would have a different derivation template and not match.
- **Test:** Manual.

### TINYMAN-08: Tinyman pool swap returns wrong asset
- **Verdict:** Defended.
- **Code:** Output measurement is on the router's holding of `asset_out`; if the pool returns a different asset, measurement is zero.
- **Test:** Adversarial pool test.

### TINYMAN-09: Tinyman pool with fee = 0
- **Verdict:** Defended.
- **Code:** Valid Tinyman pool; the router's measurement reflects the actual output.
- **Test:** Manual.

### TINYMAN-10: Tinyman pool with fee = 100% (no output)
- **Verdict:** Defended.
- **Code:** Output = 0; route reverts at floor assertion.
- **Test:** Manual.
