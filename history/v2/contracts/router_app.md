# Router Application Review

## Entry points

| Method | Security role | Review result |
|---|---|---|
| `route` | two-hop execution | balance-delta, floor, hygiene and path checks reviewed |
| `route3` | three-hop execution | same controls; sanitisation tested in emulated context |
| `opt_in_asset` | temporary input opt-in | route-bound and group-clean |
| `verify_discount` | optional fee voucher | signer, domain and length checks |
| `pool_budget` | no-op opcode budget call | permissionless but stateless |
| `set_admin` | admin rotation | admin-only, non-zero |
| `set_escrow` | treasury destination | admin-only, non-zero and opted in |
| `set_fee` | fee rate | admin-only, <= 100 bps |
| `set_voucher_signer` | discount key | admin-only, 32-byte key |
| `set_quote_signer` | route floor account | admin-only, non-zero and never unset |
| `set_conversion_pool` | treasury venue approval | admin-only, full `Leg` stored |
| `close_holding` | admin cleanup | empty holding required |
| `convert_and_distribute` | treasury conversion | admin-only, bounds, approved pool and floor |
| `delete_application` | retirement | admin-only, no accrued fees/assets |

## Critical data-flow properties

### Input

`_input_amount` verifies the funding sender, receiver, asset and adjacency.
For an ASA, the route records the post-funding holding and checks after the
first provider leg that exactly `amount_in` was consumed.

### Intermediate

`_swap_leg` snapshots the destination holding before the provider call and
returns the balance delta. That value, not a provider log, is passed to the
next leg. Intermediates opened for the route are asserted empty and closed.

### Output

The final output is paid to `Txn.sender`. The destination holding is closed if
the route opened it. `_group_paid` totals this application's earlier route
return logs only for the same output asset and the current call's own result.

### Floor

`_signed_floor` reads the final group transaction, checks the configured quote
signer, requires a `pool_budget()` application call to this application, and
checks the note's application, caller, output asset, per-index amount and
asserting route. The signer transaction's validity window supplies expiry.

### External providers

- Tinyman v2 pool address is reconstructed from validator and pair assets.
- Pact and STAMM pool apps are creator-pinned.
- AlgoFi pool apps are listed and its manager is pinned.
- STAMM scores box and budget applications must be named by the outer call.

Creator pinning is a provider trust boundary, not code immutability. See M4.

### Treasury

Conversion reads the stored seven-field `Leg`, sends output only to the
platform escrow, and decrements `accrued` only after the swap and floor pass.
The final-sweep exception is now limited to dust below the configured economic
floor. A stolen admin key remains able to redirect the escrow by design.
