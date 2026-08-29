# Economic / MEV Attack Vectors

These vectors analyze economic attacks: sandwich, front-running, oracle manipulation, donation attacks, and similar.

Algorand's consensus architecture significantly reduces the attack surface compared to EVM chains:

- No public mempool means sandwich attacks are not feasible in the classic sense.
- Block proposers are pseudorandom and rotated frequently.
- Transaction ordering within a block is determined by the proposer but cannot be observed by external attackers before the block is committed.

The router's defence is the floor mechanism (`_signed_floor`) which prevents predatory execution even if a transaction is observed.

## Vectors

### GENERAL-ECON-01: Classic sandwich attack
- **Verdict:** Not applicable.
- **Code:** Algorand has no public mempool; sandwich attacks are not feasible.
- **Test:** n/a.

### GENERAL-ECON-02: Front-running a swap
- **Verdict:** Not applicable.
- **Code:** The quote-server signature binds the floor to the specific caller's input amount, so front-running with a different input amount would not clear the floor assertion.
- **Test:** Manual.

### GENERAL-ECON-03: Oracle manipulation
- **Verdict:** Not applicable.
- **Code:** The router does not read oracles. All prices come from pool reserves, which are observed in the same atomic group as the swap.
- **Test:** n/a.

### GENERAL-ECON-04: Donation attack on pool reserves
- **Verdict:** Defended.
- **Code:** The router does not rely on pool reserves for output calculation. It measures output by balance delta. A donation would not affect the user's output (the pool's curve math would, but the user's actual output is what the pool delivers, not what the curve predicts).
- **Test:** Manual adversarial pool test.

### GENERAL-ECON-05: Slippage tolerance zero (user accepts no slippage)
- **Verdict:** Defended.
- **Code:** The floor mechanism asserts `actual >= floor`. If floor = 0, any output (including zero) passes. The risk is the user setting floor = 0 themselves; the contract does not prevent this but the quote server signs a floor that respects the user's stated slippage.
- **Test:** Manual.

### GENERAL-ECON-06: Fee skim manipulation
- **Verdict:** Defended (E1 v3 invariant).
- **Code:** `set_fee` asserts `fee_bps <= MAX_FEE_BPS = 100`. The skim computes `amount * fee_bps // BASIS_POINTS` exactly.
- **Test:** `tests/test_router_contract.py::test_fee_ceiling`.

### GENERAL-ECON-07: Voucher signer discount manipulation
- **Verdict:** Defended (E4 v3 invariant).
- **Code:** `verify_discount` rebuilds the voucher message and verifies the signature against `voucher_signer`. `discount <= MAX_DISCOUNT` is asserted.
- **Test:** Manual.

### GENERAL-ECON-08: TWAP oracle manipulation
- **Verdict:** Not applicable.
- **Code:** The router does not use a TWAP oracle.
- **Test:** n/a.

### GENERAL-ECON-09: Flash-loan style swap
- **Verdict:** Defended.
- **Code:** Algorand has no flash loans. A same-group add+remove is not profitable because the router does not own reserves to manipulate.
- **Test:** n/a.
