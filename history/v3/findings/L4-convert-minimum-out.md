# [LOW] L4: Fee Conversion Minimum Output Validation

## Location
`contracts/router_app.py:convert_and_distribute`

## Description
Allowing `minimum_out = 0` during normal fee conversions permits sandwich attacks or conversion against illiquid pools with 100% slippage loss.

## Remediation
Enforced `minimum_out > 0` for all standard conversions:
```python
assert minimum_out > 0 or (
    batch == self.accrued
    and batch < TemplateVar[UInt64]("MIN_CONVERSION_BATCH")
), (
    "a conversion must state a floor unless it is a final sweep"
)
```
*Note: A zero floor is permitted exclusively for final sub-floor dust sweeps where the output may round to zero.*

## Status
**Patched and Verified.**
