# Access control, derived from the source

Produced by parsing `contracts/router_app.py` for decorated entry points and
the guards inside each body, rather than read off by eye. Reproduce with
[verification/verify.sh](../verification/verify.sh).

## The 15 entry points

| method | admin | `RESTRICT_TO_ADMIN` | group hygiene | additional |
|---|:---:|:---:|:---:|---|
| `set_admin` | ✓ | | ✓ | non-zero address |
| `set_escrow` | ✓ | | ✓ | non-zero address |
| `set_fee` | ✓ | | ✓ | `fee_bps <= MAX_FEE_BPS` (100) |
| `set_voucher_signer` | ✓ | | ✓ | |
| `set_quote_signer` | ✓ | | ✓ | |
| `set_conversion_pool` | ✓ | | ✓ | |
| `set_paused` | ✓ | | ✓ | stops `route`/`route3` only |
| `convert_and_distribute` | ✓ | | ✓ | pool read from state; no same-group approval |
| `delete_application` | ✓ | | ✓ | accrued must be 0; no holdings open |
| `close_holding` | ✓ | ✓ | ✓ | |
| `route` | ✓ | ✓ | ✓ | co-signed floor |
| `route3` | ✓ | ✓ | ✓ | co-signed floor |
| `opt_in_asset` | | | ✓ | must serve a route in the same group |
| `verify_discount` | | | — | ed25519 voucher over a rebuilt message |
| `pool_budget` | | | — | |

`RESTRICT_TO_ADMIN` is a compile-time template variable. Every mainnet
deployment to date has set it; testnet does not.

`set_paused` stops `route` and `route3` in one transaction — the mechanism
that has to exist before the restriction comes off, since while it is set the
restriction is also the only stop button. See
[going-unrestricted.md](going-unrestricted.md).

## `_assert_group_is_clean`

Called by 13 of the 15. It walks **every transaction in the group** and refuses
if any carries:

- `rekey_to != Global.zero_address` — a rekey hands the account away permanently
- `close_remainder_to != Global.zero_address` — drains the ALGO balance
- `asset_close_to != Global.zero_address` — drains an ASA holding

This is what makes a routed group safe to sign as one click. The attack it
refuses is attaching a close or a rekey to the same approval that authorises a
trade.

### The two that do not call it

`verify_discount` and `pool_budget`. Both write no state, send no inner
transaction and return nothing; they exist to add opcode budget and to
authenticate a fee voucher.

The argument that this is safe is atomicity, not triviality. Any group that
does something runs `route`, `route3` or an admin method, and each of those
asserts hygiene over the whole group — so a rekey sitting beside a
`pool_budget` call is refused by the route in the same group, and a group with
no route does nothing worth protecting.

`pool_budget`'s docstring adds a reason a second sweep would be actively
harmful: walking the group again spends part of the very opcode allowance the
call exists to add.

## `opt_in_asset` and the minimum-balance question

Independent analyses of comparable protocols flag unrestricted opt-ins as a
drain: each costs the application 0.1 ALGO of minimum balance, and an attacker
who opens holdings for junk assets locks that balance until an administrator
sweeps it.

Closed here, structurally:

```python
assert not op.AssetHoldingGet.asset_balance(
    Global.current_application_address, asset.id
)[1], "already opted in"
assert self._routed_in_group(asset.id), "an opt-in must serve a route"
```

An opt-in can only be opened when a `route` or `route3` call **in the same
group** will use that asset, and that route closes the holding before the group
ends. The minimum balance is therefore borrowed and returned inside one atomic
group, and there is no path that leaves one open.

### The fragile part, and the test that holds it

`_routed_in_group` proves a route is present by comparing the call's selector
against `arc4_signature(ROUTE_SIGNATURE)` — where `ROUTE_SIGNATURE` is a
**string literal the contract carries**, not something the compiler derives.

Change the `Leg` struct and the compiled selector moves while the literal stays
behind. Nothing fails to compile. What fails is every ASA route, on the
opt-in's own assert, once deployed — which is exactly what happened when
`opups` was added to `Leg`: the mainnet deployment answered `assert failed
pc=659` until the literals caught up.

`tests/test_router_contract.py::TestTheHandWrittenSignatures` compares the
literals against the contract's own ABI and is what catches it next time.
Verified passing at the audited revision.
