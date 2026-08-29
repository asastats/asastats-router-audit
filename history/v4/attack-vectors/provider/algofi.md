# AlgoFi Attack Vectors

AlgoFi pools are application calls with a manager app reference. The router's defence is the curated whitelist of 23 pools in `ALGOFI_POOLS`. AlgoFi is defunct; the list is intended for legacy routing.

## Vectors

### ALGOFI-01: Pool not in whitelist
- **Verdict:** Defended.
- **Code:** `_assert_listed` checks the pool app ID is in `ALGOFI_POOLS`.
- **Test:** `tests/test_router_contract.py::test_algofi_pool_must_be_listed`.

### ALGOFI-02: Manager app is malicious
- **Verdict:** By design.
- **Code:** The manager app is part of the AlgoFi design; the router includes it in the leg's `apps` field.
- **Test:** Manual.

### ALGOFI-03: AlgoFi pool with extreme fee
- **Verdict:** Defended.
- **Code:** Output measured by balance delta; floor protects user.
- **Test:** Manual.

### ALGOFI-04: AlgoFi pool with one-sided reserve (invalid)
- **Verdict:** Defended.
- **Code:** AlgoFi pool reverts; route reverts.
- **Test:** Manual.

### ALGOFI-05: AlgoFi pool with fee denormalisation
- **Verdict:** Defended.
- **Code:** Off-chain curve (`algofi_constant_product_out`) matches on-chain behaviour to ±1 microunit; floor protects.
- **Test:** `tests/test_curves.py::TestAlgoFi`.

### ALGOFI-06: AlgoFi pool reserves manipulable
- **Verdict:** Not applicable.
- **Code:** Algorand atomic groups.
- **Test:** n/a.

### ALGOFI-07: AlgoFi pool reactivated after being in defunct list
- **Verdict:** Defended.
- **Code:** If AlgoFi reactivates a pool, the list remains valid (pools still routable). The list is curated; additions are admin-controlled.
- **Test:** n/a.

### ALGOFI-08: AlgoFi pool swap takes input but returns nothing
- **Verdict:** Defended.
- **Code:** Output = 0; floor assertion fails.
- **Test:** Adversarial pool test.

### ALGOFI-09: AlgoFi pool overpays (rounding direction)
- **Verdict:** Defended.
- **Code:** Output is the actual amount received.
- **Test:** Adversarial pool test.

### ALGOFI-10: AlgoFi pool sends to wrong recipient
- **Verdict:** Defended.
- **Code:** Router measurement on its own holding; pool's recipient error results in zero measurement.
- **Test:** Adversarial pool test.
