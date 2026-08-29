# C1 — Permissionless `convert_and_distribute` can drain accrued fees

**Severity:** Critical  
**Location:** `router/contracts/router_app.py`, `convert_and_distribute`  
**Status:** Patched in source (admin-only)

## Description

`convert_and_distribute` is designed to swap accrued ALGO platform fees into ASASTATS and send them to the platform escrow. It is permissionless so that fees do not stall if the keeper is offline.

The method takes a `Leg` argument that names the pool to convert through. Because the contract dispatches to provider-specific leg logic based only on `leg.provider` and `leg.app`, a caller can name **any application** as the conversion pool.

## Attack scenario

1. The attacker deploys a malicious Algorand application whose address will receive the ALGO deposit.
2. The attacker calls `convert_and_distribute` with a `Leg` whose `provider` is `PROVIDER_PACT` (or STAMM/AlgoFi) and whose `app` is the attacker-controlled application.
3. The router deposits the `batch` ALGO into the attacker app's escrow via `_pact_leg` and calls the app.
4. The attacker app does nothing and returns no ASASTATS.
5. The caller sets `minimum_out = 0`, so the assertion `received >= minimum_out` passes.
6. `self.accrued -= batch` succeeds.
7. The ALGO is now in the attacker-controlled escrow and cannot be recovered.

The `MAX_CONVERSION_BATCH` cap limits the amount per call, but the attacker can repeat the call until `accrued` is exhausted.

## Impact

Total loss of all accrued platform fees. Accrued fees are platform revenue, not user funds, but they can grow to tens or hundreds of ALGO over time.

## Why it was missed

The existing tests exercise the batch bounds (`batch <= accrued`, `batch >= MIN_CONVERSION_BATCH`, `batch <= MAX_CONVERSION_BATCH`) but never test with a non-admin caller or a malicious pool. The threat model treats the treasury path as lower value than the routing path, which is correct, but it still assumed the conversion pool was trustworthy.

## Fix

Make `convert_and_distribute` admin-only:

```python
assert Txn.sender == self.admin, "only the admin may convert"
```

This is the simplest and safest fix. An alternative that preserves permissionless conversion is to maintain an admin-controlled whitelist of approved conversion pools and assert that the supplied `Leg` matches one of them. The admin-only fix is preferred because:

- The admin already controls the fee rate, the escrow, and retirement.
- A keeper can be run under the admin key or a delegated admin.
- It removes an entire class of pool-spoofing attacks against the treasury path.

## Verification

After the patch, the existing tests in `tests/test_router_contract.py` and `tests/test_contract_localnet.py` still pass because both use the admin account to call `convert_and_distribute`. A new test should be added that verifies a non-admin call is rejected.
