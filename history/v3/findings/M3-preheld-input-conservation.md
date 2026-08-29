# [MEDIUM] M3: Incomplete Input Consumption for Pre-Held Assets

## Location
`contracts/router_app.py:_assert_input_spent`

## Description
When the router contract already holds an asset (e.g. a frequently traded intermediate), the close-on-success mechanism cannot be used to prove that Leg 1 consumed the entire input transfer. A faulty or malicious pool could consume only a portion of the input transfer and leave the rest stranded in the router.

## Remediation
Added `_assert_input_spent`:
```python
@subroutine
def _assert_input_spent(
    self, asset_in: UInt64, before: UInt64, amount: UInt64
) -> None:
    if asset_in != 0:
        assert self._held(asset_in) == before - amount, (
            "provider left input in the router"
        )
```

## Status
**Patched and Verified.**
