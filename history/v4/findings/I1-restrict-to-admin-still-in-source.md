# I1 — `RESTRICT_TO_ADMIN` Template Var Still In Source

**Severity:** Informational
**Status:** New in v4 → **Patched** (applied during v4 audit)
**Location:** `router/contracts/router_app.py:1930-1932` (in `route`), `2061-2063` (in `route3`)
**Contract:** On-chain
**Discovered:** 2026-08-22

---

## Summary

The `RESTRICT_TO_ADMIN` template variable remains in the contract source code. It is set to `1` for testnet deployments and `0` for mainnet deployments. The variable exists to prevent user access during the gradual rollout of the backend-signed-floor mechanism, but mainnet has been running unrestricted for several months.

The flag should be removed entirely for the next compile to avoid future confusion and to bring the source code in line with the deployed behaviour.

---

## Description

### Code excerpt (`router/contracts/router_app.py`)

```python
@arc4.abimethod
def route(
    self,
    asset_in: arc4.UInt64,
    asset_middle: arc4.UInt64,
    asset_out: arc4.UInt64,
    amount: arc4.UInt64,
    hops: arc4.DynamicArray[arc4.UInt8, Leg],
    quote_note: arc4.DynamicBytes,
) -> arc4.UInt64:
    ...
    assert Txn.sender == self.admin, "RESTRICT_TO_ADMIN is set"  # line ~1931
    ...
```

```python
@arc4.abimethod
def route3(
    self,
    asset_in: arc4.UInt64,
    asset_m1: arc4.UInt64,
    asset_m2: arc4.UInt64,
    asset_out: arc4.UInt64,
    amount: arc4.UInt64,
    legs: arc4.DynamicArray[arc4.UInt8, Leg],
    quote_note: arc4.DynamicBytes,
) -> arc4.UInt64:
    ...
    assert Txn.sender == self.admin, "RESTRICT_TO_ADMIN is set"  # line ~2062
    ...
```

The template variable is set in `router/build.py` (or equivalent deployment script) and passed to `puyapy` at compile time. Both asserts evaluate to `True` (pass) when `RESTRICT_TO_ADMIN = 0` and to `Txn.sender == self.admin` when `RESTRICT_TO_ADMIN = 1`.

### Why this is informational, not a vulnerability

- The flag does not affect the mainnet deployment (it is `0`).
- The flag does not affect testnet deployments in any unsafe way (it intentionally prevents user access during rollout).
- The flag does not introduce a security weakness on either deployment.

The issue is purely **deployment hygiene**:

1. The source code disagrees with the deployed behaviour (source: restricted; mainnet: unrestricted).
2. If a future compile is performed with `RESTRICT_TO_ADMIN = 1` by accident, mainnet users would be locked out without explanation.
3. Future auditors may be confused by the source-vs-deployment mismatch.

---

## Impact

| Impact category | Severity | Rationale |
|-----------------|----------|-----------|
| Fund safety | None | Flag does not affect security. |
| Deployment hygiene | Informational | Source-vs-deployment mismatch. |
| Audit clarity | Informational | Future audits may be confused. |

---

## Recommendation

### Option 1 (preferred): Remove the flag entirely

See [IMPROVEMENTS.md](../IMPROVEMENTS.md) §3 for the code skeleton. The fix removes the template variable and the two asserts, replacing them with a comment indicating the contract is unrestricted.

```python
# The contract runs unrestricted on mainnet as of 2026-08-21
# (app ID 769636397). The RESTRICT_TO_ADMIN template variable has
# been removed; if the contract is to be re-restricted, redeploy
# with a patched version that adds the assert back.
```

### Option 2: Convert to a no-op

Replace the asserts with `assert True`:

```python
# Deprecated: RESTRICT_TO_ADMIN is no longer supported.
# This assert is a no-op kept for source compatibility.
assert True, "deprecated: RESTRICT_TO_ADMIN removed"
```

This is more conservative (no source-code change) but leaves the dead code in place.

### Option 3: No change

Document the flag's presence in `router/SECURITY.md` and rely on the deployment script to set it correctly.

---

## Cross-references

- Improvement: [IMPROVEMENTS.md](../IMPROVEMENTS.md) §3
- Code location: `router/contracts/router_app.py:1930-1932`, `2061-2063`
- Deployment script: `router/scripts/deploy.py` (sets the template variable)
- Severity rationale: [methodology/scope.md §6](../methodology/scope.md)
