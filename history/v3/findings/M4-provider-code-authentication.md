# [MEDIUM] M4: External Provider Pool Code Authentication vs Creator Pinning

## Location
`contracts/router_app.py:_assert_created_by`, `_assert_listed`, `_tinyman_v2_pool`

## Description
The router interacts with external pool contracts across multiple DEXes. If an attacker can supply an arbitrary pool application ID, they could direct funds to an attacker-controlled application.

## Remediation & Analysis
The contract enforces four distinct authentication strategies tailored to each DEX:
1. **Tinyman v2:** Derived deterministic logic signature address based on bytecode hash and asset pair.
2. **Pact AMM:** Validates on-chain creator address against pinned official deployers (`PACT_POOL_CREATORS`).
3. **STAMM:** Validates on-chain creator address against pinned official deployer (`STAMM_POOL_CREATORS`).
4. **AlgoFi:** Validates application ID against a curated whitelist (`ALGOFI_POOLS`) and pins manager ID (`ALGOFI_MANAGER_APP_ID`).

*Note on residual trust:* Creator pinning trusts the official DEX deployer key not to deploy malicious bytecode in the future. Full bytecode hashing on-chain is prohibitive due to AVM opcode limits and multiple live compiler variants.

## Status
**Patched and Verified (with accepted operational trust assumption).**
