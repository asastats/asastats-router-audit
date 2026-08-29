# Slippage Attack Vectors

These vectors analyze attacks that exploit slippage protection. The router's defence is the floor mechanism: the backend quote server signs a floor that the contract asserts.

## Vectors

### ROUTE-SLIP-01: Frontend sets floor to zero
- **Verdict:** Defended (H1 v3).
- **Code:** `_signed_floor` reads the floor from the backend-signed transaction note, not from the route's ABI arguments. The frontend cannot set the floor.
- **Test:** `tests/test_router_contract.py::test_widget_cannot_zero_floor`.

### ROUTE-SLIP-02: Quote server signs floor of zero
- **Verdict:** By design.
- **Code:** The contract accepts a floor of zero (no protection). The quote server's policy determines whether zero floors are ever signed.
- **Test:** Manual.

### ROUTE-SLIP-03: Quote server's signature is replayed on a different swap
- **Verdict:** Defended (D2 v3 invariant).
- **Code:** `_signed_floor` checks (app_id, caller, output, per-index input amounts, asserting index). A signature for one trade cannot be replayed on another.
- **Test:** Manual.

### ROUTE-SLIP-04: Quote server signs floor for output asset X, route uses asset Y
- **Verdict:** Defended.
- **Code:** `_signed_floor` checks the output asset matches the signed note.
- **Test:** Manual.

### ROUTE-SLIP-05: Quote server signs floor with different input amount than actual
- **Verdict:** Defended.
- **Code:** `_signed_floor` checks per-index input amounts match.
- **Test:** Manual.
