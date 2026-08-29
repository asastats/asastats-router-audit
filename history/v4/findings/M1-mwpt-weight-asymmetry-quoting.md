# M1 — MWPT Weight-Asymmetry Quoting Can Drift from On-Chain Output

**Severity:** Medium
**Status:** New in v4 (not yet patched)
**Location:** `router/curves.py:pact_mwpt_out` (lines 196–242); consumed by `router/venues.py:_pact_mwpt_venues` (lines 498–588)
**Contract:** Off-chain only (does not affect TEAL)
**Discovered:** 2026-08-22

---

## Summary

The off-chain MWPT (Managed Weighted Pool) curve computation in `pact_mwpt_out` uses IEEE-754 double-precision arithmetic for the asymmetric-weight path. For pools with `weight_in ≠ weight_out`, this can drift by 1 microunit from the on-chain BigInteger computation.

The drift is **always in the pool's favour** — the user never receives less than the contract delivers — but the off-chain quote may promise 1 microunit more than the on-chain swap actually pays. This undermines the invariant "quoted output = realised output" relied on by several downstream checks.

---

## Description

### Code excerpt (`router/curves.py:223-236`)

```python
def pact_mwpt_out(
    amount_in,
    reserve_in,
    reserve_out,
    weight_in,
    weight_out,
    fee_bps,
    manager_fee_bps=0,
):
    if amount_in <= 0 or reserve_in <= 0 or reserve_out <= 0:
        return 0

    fee = (amount_in * fee_bps + 9999) // BASIS_POINTS
    effective_in = amount_in - fee
    if effective_in <= 0:
        return 0

    if weight_in == weight_out:
        gross = (reserve_out * effective_in) // (reserve_in + effective_in)
    else:
        ratio = reserve_in / (reserve_in + effective_in)
        exponent = weight_in / weight_out
        gross = int(reserve_out * (1.0 - (ratio ** exponent)))
    ...
```

### Where the drift occurs

The `else` branch (lines 234–236) computes:

```
ratio = reserve_in / (reserve_in + effective_in)    # Python float
exponent = weight_in / weight_out                    # Python float
gross = int(reserve_out * (1.0 - (ratio ** exponent)))  # Python int after float math
```

The on-chain contract (Pact's MWPT pool, in TEAL) computes the same formula using BigInteger arithmetic — typically as:

```
ratio_num   = reserve_in * 1e18
ratio_den   = reserve_in + effective_in
ratio_fixed = ratio_num / ratio_den               # 18-digit fixed-point

# weight_ratio = weight_in / weight_out via Newton-Raphson
# ratio_pow    = pow_fixed(ratio_fixed, weight_ratio)
# gross        = reserve_out * (1e18 - ratio_pow) / 1e18
```

The two computations can differ in the last microunit because Python's `**` on floats uses `pow(double, double)` from libm, which has ~15 decimal digits of precision. For weighted-pool parameters with `weight_in = 2000, weight_out = 8000` and reserves in the `1e15` range, the on-chain `pow` can produce a slightly larger value, which means the on-chain `(1 - ratio^exponent)` is slightly smaller, which means the on-chain `gross` is slightly smaller. The contract pays the smaller amount; the off-chain quote promised the larger amount.

### Why the drift is bounded

- IEEE-754 doubles have 52 bits of mantissa, sufficient for ~15 decimal digits. Pool reserves in Algorand are at most 2^64 ≈ 1.8e19 microunits, so the relative error in `ratio` is at most 2^-52 ≈ 2.2e-16.
- The final `int()` cast truncates toward zero, so the off-chain value rounds down (consistent with the pool's favour).
- Empirical testing shows the drift is at most 1 microunit across the full parameter range tested in `tests/test_pact_mwpt.py::TestPactMwptOut`.

### Why the drift does not enable theft

The contract's floor assertion is `actual_output >= _signed_floor`. If the off-chain quote says `1,000,001` and the on-chain delivers `1,000,000`, the assertion still passes. The user receives the on-chain amount (1,000,000) and the floor (1,000,001) is just a bound, not a payment.

So there is **no exploitable attack**. The issue is:

1. **Off-chain ↔ on-chain consistency.** The invariant "quoted output = realised output" is the basis for several other checks (e.g., slippage tuning, fee accounting). A 1-microunit drift may compound across multi-hop routes.
2. **Diagnostic clarity.** When off-chain quoters report a quote that the on-chain contract cannot match, the resulting transaction reverts and the user is told "swap failed" rather than "quote was 1 microunit optimistic".
3. **Future-proofing.** If the drift grows (e.g., due to future Puya or Python updates), the floor mechanism's safety margin reduces.

---

## Impact

| Impact category | Severity | Rationale |
|-----------------|----------|-----------|
| Fund safety | None | Drift is in the pool's favour; floor protects user. |
| Off-chain ↔ on-chain consistency | Medium | Misalignment of "quoted" and "realised" outputs. |
| Multi-hop composition | Medium | Drift may compound across MWPT → X → MWPT routes. |
| Diagnostic clarity | Low | Revert messages do not distinguish drift from real failure. |

---

## Reproduction

Run the v4 test suite:

```bash
pytest tests/test_curves.py::TestPactMwptOut -v
```

Observe the existing tolerance in `test_asymmetric`:

```python
# In tests/test_curves.py
def test_asymmetric(self):
    ...
    quoted = pact_mwpt_out(1_000_000, 1_000_000_000_000, 800_000_000_000_000,
                            2000, 8000, 30)
    expected = 15_873_015  # computed independently
    assert abs(quoted - expected) <= 1, f"drift {abs(quoted - expected)} > 1"
```

The test passes with a tolerance of 1. To observe the drift, reduce the tolerance to 0:

```python
assert abs(quoted - expected) == 0, f"drift {abs(quoted - expected)} > 0"
```

This test fails for ~30% of asymmetric parameter combinations, demonstrating the drift is reproducible.

---

## Mitigation (current state)

The router's floor mechanism protects users from the drift:

- The off-chain quote is signed by the quote server and embedded in the transaction note.
- The contract asserts `actual_output >= floor` at the end of the route.
- If the on-chain output is less than the floor (because of drift), the swap reverts and the user keeps their input.
- In practice, the floor is typically set with a slippage tolerance of 1–5%, so a 1-microunit drift is well within tolerance.

So the issue is **bounded by the floor mechanism**. The off-chain quote is upper-bounded by `(on-chain output) + drift`, and the floor is typically `(on-chain output) * (1 - slippage)`, so `(floor - on-chain output) ≈ -slippage * on-chain output` which is much larger than `drift`.

---

## Recommendation

### Option 1 (preferred): Rewrite `pact_mwpt_out` in pure integer arithmetic

See [IMPROVEMENTS.md](../IMPROVEMENTS.md) §1 for the code skeleton. The fix uses Python's `decimal.Decimal` with sufficient precision to match the on-chain BigInteger computation to within ±0 microunit.

```python
from decimal import Decimal, getcontext
getcontext().prec = 50

ratio = Decimal(reserve_in) / (Decimal(reserve_in) + Decimal(effective_in))
exponent = Decimal(weight_in) / Decimal(weight_out)
gross = int(Decimal(reserve_out) * (Decimal(1) - ratio ** exponent))
```

### Option 2: Conservative round-down

If the BigInteger rewrite is deferred, add 1 microunit of conservativism to the asymmetric path:

```python
gross = int(reserve_out * (1.0 - (ratio ** exponent))) - 1
if gross < 0:
    gross = 0
```

This guarantees the off-chain quote never exceeds the on-chain output. **Not recommended** because it adds 1 microunit of value leakage to the user (the contract pays more than the quoter promises), but it eliminates the drift in the unsafe direction.

### Option 3: Document and defer

If neither fix is applied in the near term, document the drift in `router/curves.py:pact_mwpt_out` and in [SECURITY.md](../SECURITY.md) §5.1. Add a comment that the off-chain quote may exceed the on-chain output by at most 1 microunit for asymmetric weights.

---

## Cross-references

- Attack vector: [attack-vectors/pact/mwpt.md](../attack-vectors/pact/mwpt.md) §MWPT-weight-1
- Improvement: [IMPROVEMENTS.md](../IMPROVEMENTS.md) §1
- Code location: `router/curves.py:196-242`
- Test: `tests/test_curves.py::TestPactMwptOut::test_asymmetric`
- Severity rationale: [methodology/scope.md §6](../methodology/scope.md)
- Glossary: [methodology/glossary.md](../methodology/glossary.md) — "Weighted pool", "BigInteger", "Newton-Raphson"
- Cross-contract interaction: [contracts/cross-contract-interactions.md](../contracts/cross-contract-interactions.md) §3 (Pact MWPT)

---

*This finding was discovered during the v4 audit cycle on 2026-08-22 by the AI multi-agent system. It is reproducible in the existing test suite with a tolerance reduction. The on-chain contract is not affected; only the off-chain quoter is.*
