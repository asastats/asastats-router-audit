# M6 — Tinyman v2 validator upgrade risk

**Severity:** Medium  
**Location:** `router/contracts/router_app.py`, `_tinyman_v2_pool`  
**Status:** Accepted / deployment risk

## Description

`_tinyman_v2_pool` rebuilds the pool logic-signature address from `TemplateVar[UInt64]("TINYMAN_V2_APP_ID")` and the two assets. If Tinyman ever upgrades its validator application, the old validator app ID will still produce the old pool addresses, but those pools may be deprecated or have no liquidity.

## Impact

- Routes through Tinyman v2 may fail or execute against deprecated pools.
- A new deployment is required to point at a new validator.

## Fix / Status

This is an inherent property of deriving pool addresses deterministically. The recommended mitigation is:

- Treat each Tinyman validator version as a separate deployment.
- Monitor Tinyman governance for validator upgrades.
- Document this as a deployment assumption in `router/SECURITY.md`.

No source change is required.
