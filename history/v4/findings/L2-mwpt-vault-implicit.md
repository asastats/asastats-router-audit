# L2 — MWPT Vault Address Is Implicit (Derived from Pool Params), Not Asserted

**Severity:** Low
**Status:** New in v4 (not yet patched)
**Location:** `router/contracts/router_app.py:_pact_leg` (lines 1486–1523); off-chain `router/legs.py:pact_mwpt_leg` (lines 232–283)
**Contract:** On-chain (the assert is missing from `_pact_leg`)
**Discovered:** 2026-08-22

---

## Summary

The MWPT pool's vault application ID is discovered off-chain by `router/venues.py:_pact_mwpt_venues` (which reads it from the pool's global state) and embedded in the leg's `foreign_apps` array. The on-chain `_pact_leg` does not verify that this vault reference matches the pool's on-chain vault.

A compromise of the off-chain quoter could substitute a malicious vault app ID. While the deposit goes to the pool's own address (not the vault's), the `boxes` array reads from the substituted vault, which could in principle be used to inject incorrect reserve data into a quoter that re-reads reserves during routing.

---

## Description

### Off-chain vault discovery

```python
# router/venues.py:_pact_mwpt_venues (lines 498-588)
def _pact_mwpt_venues(client, app_id, ...):
    pool_state = client.application_info(app_id)
    vault_app_id = pool_state["global_state"]["vault"]  # read from pool
    ...
    return PactMwptPool(
        app_id=app_id,
        vault_app_id=vault_app_id,
        ...
    )
```

### Off-chain vault reference in the leg

```python
# router/legs.py:pact_mwpt_leg (lines 232-283)
def pact_mwpt_leg(pool, sender, asset_in_id, amount_in, minimum_out, ...):
    pool_app = pool.app_id
    vault_app = pool.vault_app_id
    return [
        itxn.AssetTransfer(...),  # deposit
        itxn.ApplicationCall(
            app_id=pool_app,
            app_args=(PACT_MWPT_SWAP, op.itob(minimum_out)),
            foreign_apps=[vault_app],   # <-- vault reference here
            foreign_assets=[asset_a, asset_b],
            boxes=[
                (vault_app, asset_a_bytes),
                (vault_app, asset_b_bytes),
            ],
            ...
        ),
    ]
```

### On-chain dispatch (the missing assert)

```python
# router/contracts/router_app.py:_pact_leg (lines 1486-1523)
@subroutine
def _pact_leg(self, leg, asset_in, asset_out, amount):
    pool_app = Application(leg.app.native)
    pool = pool_app.address
    creator, exists = op.AppParamsGet.app_creator(pool_app)
    is_mwpt = creator == Account(MWPT_FACTORY_CREATOR)
    swap_arg = Bytes(PACT_MWPT_SWAP) if is_mwpt else Bytes(PACT_SWAP)
    # ... build inner transaction with foreign_apps including vault
    # **No assertion that the vault in foreign_apps matches the pool's on-chain vault.**
```

### Threat model

The off-chain quoter (`router/router/`) is operated by the platform. A compromise of the quoter is a *different* threat than a compromise of the contract. The two threat surfaces are:

1. **Contract compromise** → would require breaking TEAL, defeating the floor, defeating the pool creator check, or defeating the group-cleanup check. These are the surfaces v3 covered.
2. **Quoter compromise** → an attacker who controls the off-chain quoter can:
   - Quote incorrect expected outputs (but the floor still protects the user).
   - Quote incorrect pool references (but the pool creator check still authenticates the pool itself).
   - **Substitute a malicious vault reference** (this finding's concern).

For (2), the question is: what does a substituted vault reference enable?

- The MWPT pool's swap method reads reserves from the **vault** app via `app_global_get_ex(vault, key)`. If the vault reference is malicious, the malicious vault returns whatever reserves it likes.
- The malicious vault then returns "favourable" reserves, and the MWPT pool computes a swap output based on those reserves.
- The router measures output by `_held(asset_out) - before`, so the user receives the *actual* pool output, not the malicious-vault-reported amount.

So a malicious vault reference **does not enable fund theft** — the user still receives the pool's actual output, and the floor still asserts `actual ≥ floor`.

The risk is:

- **Diagnostic clarity:** the quoter reports a different output than the pool delivers, leading to user confusion.
- **Quoter-level attacks:** if a downstream quoter uses the vault-reported reserves for further computation (e.g., a quote that includes the vault-reported reserves in a slippage calculation), the malicious vault can manipulate that calculation.

The router's contract itself does not perform further computations on the vault-reported reserves. So the residual risk is **off-chain only**.

---

## Impact

| Impact category | Severity | Rationale |
|-----------------|----------|-----------|
| Fund safety (on-chain) | None | Pool creator check + balance delta measurement still protect user. |
| Off-chain trust | Low | A quoter compromise could substitute the vault reference; the impact is limited to off-chain diagnostics. |
| Diagnostic clarity | Low | "Quote X delivered Y" mismatches can confuse operators. |

---

## Reproduction

This finding is conceptual rather than directly reproducible. To trigger the issue:

1. Compromise the off-chain quoter (`router/router/`).
2. Substitute a malicious vault app ID in the leg's `foreign_apps` array.
3. Observe that the on-chain `_pact_leg` accepts the leg without complaint.
4. The swap succeeds (or fails) based on the malicious vault's behaviour; the user is unaffected.

---

## Mitigation (current state)

None directly. The contract relies on the off-chain quoter to provide a correct vault reference.

Indirect mitigations:

- **Pool creator check** (`_assert_created_by`) still authenticates the MWPT pool itself.
- **Balance delta measurement** (`_held(asset_out) - before`) ensures the user receives the actual output, not the reported output.
- **Floor mechanism** (`_signed_floor`) ensures the user receives at least the floor amount.

---

## Recommendation

### Option 1 (preferred): Add an on-chain vault verification assert

See [IMPROVEMENTS.md](../IMPROVEMENTS.md) §2 for the code skeleton. The fix adds an `app_global_get_ex` call in `_pact_leg` to read the pool's on-chain vault reference and asserts that the supplied vault matches.

```python
if is_mwpt:
    # Verify vault reference in foreign_apps matches the pool's on-chain vault.
    # This adds one extra app_global_get_ex but no extra inner transaction.
    on_chain_vault, vault_exists = op.AppGlobal.get_ex(
        pool_app, Bytes(b"V")  # MWPT vault key
    )
    assert vault_exists, "MWPT pool missing vault reference"
    assert leg.apps[0].native == on_chain_vault.native, \
        "MWPT vault mismatch"
```

### Option 2: Document the trust assumption

Add a comment to `_pact_leg`:

```python
# Note: the MWPT vault reference in leg.apps is trusted to be correct.
# A compromised off-chain quoter could substitute a malicious vault.
# The on-chain pool creator check still authenticates the pool itself,
# and the user's output is measured by balance delta, so this is not
# an exploitable attack. Future hardening: add an assert that the
# vault matches the pool's on-chain vault.
```

### Option 3: Move vault discovery on-chain

A more invasive refactor: remove the off-chain vault discovery and have the contract look up the vault itself via `app_global_get_ex`. This requires a transaction-size budget increase (one extra `app_global_get_ex` per MWPT leg) but eliminates the off-chain trust gap entirely.

---

## Cross-references

- Attack vector: [attack-vectors/pact/mwpt.md](../attack-vectors/pact/mwpt.md) §MWPT-vault-1
- Improvement: [IMPROVEMENTS.md](../IMPROVEMENTS.md) §2
- Code location: `router/contracts/router_app.py:1486-1523`
- Off-chain code: `router/legs.py:232-283`, `router/venues.py:498-588`
- Severity rationale: [methodology/scope.md §6](../methodology/scope.md)
- Glossary: [methodology/glossary.md](../methodology/glossary.md) — "MWPT vault", "box reference"
