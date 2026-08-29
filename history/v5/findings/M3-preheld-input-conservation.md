# Finding M3: Pre-Held Asset Input Conservation

- **Severity:** Medium
- **Category:** Accounting / Funds Conservation
- **Location:** `contracts/router_app.py:_assert_input_spent`
- **Origin:** v2 Audit (2026-08-13)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
If the router account was already opted into an asset prior to a route, an external pool in Leg 1 that consumed only part of the caller's input would leave the remainder stranded in the router without failing the zero-balance close check.

---

## 2. Remediation in Code
Implemented `_assert_input_spent`:
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
Invoked in both `route` and `route3` immediately after Leg 1 execution.

---

## 3. Verification Evidence
- `TestAdversarialPools::test_a_pool_leaving_input_in_a_preheld_router_balance_is_rejected` passes.
- `TestRouting::test_the_route_leaves_this_balance_exactly_as_it_found_it` passes.
