# M1 — Route paths are not sanitised

**Severity:** Medium  
**Location:** `router/contracts/router_app.py`, `route` / `route3`  
**Status:** Patched in source

## Description

Neither `route` nor `route3` validates that the route's assets are sensible. In particular:

- `route` does not assert `asset_in != middle` or `middle != asset_out`.
- `route3` asserts `first_middle != second_middle` but not `asset_in != first_middle`, etc.
- No method prevents a cycle such as A → B → A.

A cycle wastes fees and could be used to grief or confuse accounting. More importantly, it indicates that the contract trusts the off-chain quoter for path validity, which is a useful invariant to enforce on-chain.

## Impact

- User can execute a route that returns the same asset they sold, paying fees and network costs.
- Off-chain bugs or malicious builder code can produce nonsensical paths that the contract accepts.

## Fix

Added a helper `_assert_distinct_assets(asset_in, middles, asset_out)` that asserts all route assets are pairwise distinct. This is called at the start of `route` and `route3`.

## Note

This check does not prevent a route through two different pools for the same pair, which may be legitimate. It only prevents the same asset appearing twice in the path.
