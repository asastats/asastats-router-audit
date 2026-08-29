# Value Conservation Attack Vectors

These vectors analyze attacks that violate value conservation across multi-hop swaps: theft, leakage, dust accumulation, or unintended value creation.

The router's defence is balance-delta measurement at every leg, and the floor mechanism at the end.

## Vectors

### ROUTE-CONS-01: Pool underpays intermediate amount
- **Verdict:** Defended.
- **Code:** The next leg uses `_held(asset_out) - before`, which reflects the actual amount received. The pool's reported amount is ignored.
- **Test:** Adversarial pool test (`MODE_NO_OUTPUT`).

### ROUTE-CONS-02: Pool overpays intermediate amount
- **Verdict:** Defended.
- **Code:** The next leg uses the actual amount received. Overpayment benefits the next leg's quote, not the user.
- **Test:** Adversarial pool test (`MODE_EXTRA_OUTPUT`).

### ROUTE-CONS-03: Pool takes input but returns nothing
- **Verdict:** Defended.
- **Code:** The next leg's measurement shows zero received, route reverts at floor assertion.
- **Test:** Adversarial pool test.

### ROUTE-CONS-04: Pool sends output to wrong address
- **Verdict:** Defended.
- **Code:** The router's measurement is on the router's own holding, not the pool's reported recipient. If the pool sends to the wrong address, the router measures zero.
- **Test:** Adversarial pool test (`MODE_WRONG_RECIPIENT`).

### ROUTE-CONS-05: Pool takes fee above declared rate
- **Verdict:** Defended.
- **Code:** The user's output is the actual amount received, regardless of the pool's declared fee. The pool may take more than declared, but the user gets whatever is delivered.
- **Test:** Adversarial pool test (`MODE_POOL_FEE`).

### ROUTE-CONS-06: ALGO skim exceeds declared fee
- **Verdict:** Defended.
- **Code:** `_skim` uses `amount * fee_bps // BASIS_POINTS` exactly. Pool fees are separate from router fees.
- **Test:** `tests/test_router_contract.py::test_skim_exact`.
