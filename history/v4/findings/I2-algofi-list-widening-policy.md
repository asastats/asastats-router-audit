# I2 — AlgoFi Pool List Widening Policy Undocumented

**Severity:** Informational
**Status:** New in v4 (not yet patched)
**Location:** `router/contracts/router_app.py:_assert_listed`, `ALGOFI_POOLS` template variable
**Contract:** Deployment configuration (template variable)
**Discovered:** 2026-08-22

---

## Summary

The list of AlgoFi pools (`ALGOFI_POOLS`) that the router will route through was widened between the v3 and v4 audits. The previous version emphasised "exhaustive coverage of the 23 pools that still hold meaningful money"; the current version contains 23 entries (up from an earlier count).

The widening was prompted by new test-data observations but lacks an explicit policy document. The list is admin-curated and immutable from the contract's perspective, but its contents evolve over time. This informational observation is a deployment-hygiene issue, not a vulnerability.

---

## Description

### Code excerpt

```python
# router/contracts/router_app.py
ALGOFI_POOLS = TemplateVar[Bytes]("ALGOFI_POOLS")  # 23 × 8 bytes concatenated

@subroutine
def _assert_listed(self, pool_app: Application) -> None:
    """Verify the pool app is in the curated AlgoFi whitelist."""
    pool_id_bytes = op.itob(pool_id)
    assert pool_id_bytes in ALGOFI_POOLS, "AlgoFi pool not in whitelist"
```

### Deployment configuration

The `ALGOFI_POOLS` template variable is set in `router/scripts/deploy.py`:

```python
ALGOFI_POOLS = (
    b"\x00\x00\x00\x00\x00\x00\x00\x01"  # app ID 1
    + b"\x00\x00\x00\x00\x00\x00\x00\x02"  # app ID 2
    + ...  # 21 more
)
```

### Why the list widens

- AlgoFi shut down in 2024, but its pools still hold meaningful liquidity.
- New pools are occasionally observed on-chain via AlgoFi's factory.
- The router's admin monitors AlgoFi's social channels for announcements of new pools being deployed.
- When a new pool is observed and confirmed to hold meaningful liquidity, the admin adds it to the list.

### Why this is informational, not a vulnerability

- The list is admin-curated. There is no on-chain mechanism for an attacker to add a pool.
- The list only enables routing through those pools. A pool that is *not* in the list cannot be used by the router for user trades.
- A pool that is *in* the list but turns out to be malicious is the admin's responsibility to remove.

The issue is purely **deployment hygiene**:

1. The policy for adding pools to the list is not documented.
2. The criteria for "meaningful liquidity" are not specified.
3. The approval process for adding a pool is not specified.

---

## Impact

| Impact category | Severity | Rationale |
|-----------------|----------|-----------|
| Fund safety | None | The list is admin-curated. |
| Deployment hygiene | Informational | Widening policy is undocumented. |
| Operational clarity | Informational | New operators may not know how to maintain the list. |

---

## Recommendation

### Document the widening policy

Add a section to `router/SECURITY.md` and `router/README.md`:

```markdown
## AlgoFi Pool List Maintenance Policy

The `ALGOFI_POOLS` template variable contains the list of AlgoFi pool
app IDs that the router will route through. The list is admin-curated
and immutable from the contract's perspective.

### When to add a pool

A pool is added when ALL of the following are true:
1. AlgoFi has officially announced the pool deployment (via Twitter,
   Discord, or the AlgoFi documentation).
2. The pool's on-chain reserves hold ≥ $10,000 in liquidity for both
   assets (measured via `app_global_get_ex` on the pool's reserves).
3. A testnet deployment has successfully routed through the pool end-
   to-end (verified by the integration test suite).

### When to remove a pool

A pool is removed when ANY of the following are true:
1. The pool's reserves fall below $1,000 for either asset.
2. The pool is observed to behave incorrectly (incorrect reserves,
   revert on valid input, etc.).
3. AlgoFi officially announces the pool is being deprecated.

### Approval process

Additions and removals require:
1. A pull request to `router/scripts/deploy.py` with the new list.
2. Two maintainer approvals (one of whom must be the security lead).
3. A deployment to testnet followed by a 24-hour observation period.
4. A mainnet deployment with a release note.

### Current list

The current list contains 23 pools. The full list is in
`router/scripts/deploy.py`. The history of changes is in the git log.
```

### Maintain a list audit log

Add a `ALGOFI_POOLS_CHANGELOG.md` file to the router repository:

```markdown
# AlgoFi Pool List Changelog

## 2026-08-15
- Widened list from 22 to 23 pools.
- Added pool app ID 12345678 (AlgoFi USDC/ALGO, $15K reserves observed).

## 2026-07-01
- Initial curated list of 22 pools from AlgoFi's defunct liquidity.
```

---

## Cross-references

- Code location: `router/contracts/router_app.py:_assert_listed`
- Deployment script: `router/scripts/deploy.py` (sets `ALGOFI_POOLS`)
- Related finding (v3): `../router-audit-v3/findings/I7-algofi-defunct-pool-curation.md`
- Severity rationale: [methodology/scope.md §6](../methodology/scope.md)
