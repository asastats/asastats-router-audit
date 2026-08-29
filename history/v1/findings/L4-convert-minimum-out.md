# L4 — `convert_and_distribute` does not require `minimum_out > 0`

**Severity:** Low
**Location:** `router/contracts/router_app.py`, `convert_and_distribute`
**Status:** **Patched**

## Description

Even after C1 made the method admin-only, it accepted `minimum_out = 0`. A
conversion with a zero floor is a conversion with no floor: `_swap_leg`
measures what arrived but has nothing to compare it against on its own, so a
pool that paid nothing would have succeeded and reduced `accrued` by the batch.

## Impact

- Accidental loss of accrued fees.

## Fix as implemented

```python
assert minimum_out > 0 or batch == self.accrued, (
    "a conversion must state a floor unless it is a final sweep"
)
```

Placed after the batch bounds, so the more specific batch messages still fire
first and an operator sees the reason closest to what they got wrong.

### The exemption is not a formality, and it was nearly missed

The first version of this fix required a floor unconditionally, and that
**reopened the trap the final-sweep exemption exists to close** - one step
further down than the original.

Dust can be worth less than one unit of the fee asset. Testnet 769092731 held
2,482 microALGO; simulating its conversion through the Pact pool it was pointed
at returned **0**, because the output rounds away before reaching one unit.
With a floor required unconditionally, `received >= minimum_out` is then
unsatisfiable for any value at or above 1, so that balance can never be
converted - and `delete_application` refuses while `accrued` is non-zero, so the
application can never be retired. The float would have been stranded exactly as
it was before `batch == accrued` was introduced.

Caught by running the testnet sweep before deploying rather than after. A
partial conversion still requires a floor, so the exemption is a door and not a
hole.

The admin quotes the pool moments before calling, so a real number is always to
hand — zero can only mean nobody looked.

## Scope, stated because the original finding overreached

The finding said "an admin mistake **or compromised admin key** could convert
accrued ALGO for nothing." Only the first half is addressed, and the second
half is not addressable here: an admin key can point `set_escrow` at itself and
convert at an honest floor. See M4 for the same limit on the pool pin.

## Verified by

`tests/test_router_contract.py::TestTheConversionFloor::test_a_zero_floor_is_refused`,
with everything else about the call in order so the guard is reached rather
than an earlier one firing.
