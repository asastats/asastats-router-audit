# Findings

32 in total across seven audits: 23 raised by v1–v5 and closed, one raised by
the contract audit, and eight by the dust sweep audit.

## Open

[`S8`](S8-transfer-alongside-a-route.md) — **a hostile transfer rides
alongside a genuine route call.** `S7` made a conversion group prove the router
is in it; nothing makes it prove the group does nothing else. The route
validates only the transaction immediately preceding it, the hygiene guard
never reads an amount or a receiver, and an extra transfer executes on its own
terms. **Open, and not closable by the method that closed `S6` and `S7`**: a
receiver whitelist refuses `sweep-6-convert`, a conversion that executed, because
a sweep legitimately pays pool escrows the browser cannot enumerate. Two partial
mitigations are recorded in that finding, and each is explicit about what it
does not cover.

The other seven are closed. The last three came from reviewing fixes rather
than code: `S6` from reviewing `S2`/`S3`, `S7` from reviewing `S6`, and `S8`
from reviewing `S7`.

Five of the eight are deployed. `S3`'s contract-side bound was the last of
those to go live, on 2026-08-30, and mainnet `3692588382` carries
`MAX_GROUP_FEE = 1_000_000`. The `S6` and `S7` fixes are in the widget and not
yet released.

One caveat that is not a finding but should not be discovered later: `S3` is
closed on the **conversion** path and cannot be closed on the **close-out**
path by any contract, because a close-out group carries no application call for
one to inspect. Mainnet still accepts a close-out group whose fees consume the
signer's entire spendable balance; the widget's `MAX_CLOSE_OUT_FEE` is the only
bound there is. See [`S3` §7](S3-unbounded-fee.md).

## Raised by the dust sweep audit

| id | severity | title | status |
|:---:|:---:|---|---|
| [`S2`](S2-forfeit-target-self-certifying.md) | Medium | The browser whitelist does not bind the forfeit destination | **Fixed** `0be86c7` / `199b9a0` |
| [`S3`](S3-unbounded-fee.md) | Medium | Nothing bounds the fee on a transaction the sweep asks a user to sign | **Fixed** `0be86c7` / `2aad22b` / contract |
| [`S4`](S4-forfeit-lacks-evaluation-veto.md) | Medium | The evaluation veto guards the opt-in path but not the automatic one | **Fixed** `2aad22b` / `9320ae2` |
| [`S5`](S5-malformed-evaluation-raises.md) | Info | A malformed evaluation took the whole sweep down rather than degrading | **Fixed** `cc9a4ff` / `d1365dc` |
| [`S6`](S6-convert-path-unchecked.md) | Medium | The conversion path is checked by nothing the engine does not choose | **Fixed** |
| [`S7`](S7-mirror-without-the-router.md) | Medium | The mirrored guard copied the cheap half and left the load-bearing one | **Fixed** |
| [`S8`](S8-transfer-alongside-a-route.md) | Medium | A hostile transfer rides alongside a genuine route call | **Open** |

None was reachable by an unprivileged remote attacker: `S2`, `S3`, `S6`, `S7`
and `S8` need the engine's response to be wrong, and `S4` needed only a wrong
price. Each of those six is rated Medium because it defeated a control built
specifically to hold under those conditions, and because the value each exposed
was unbounded.

`S5` is Informational and kept separate on purpose: it moves no value, and
grading it alongside three findings that could hand a holding to the wrong
address would misrepresent all four. It is here because it was found by the
property tests written *after* those fixes, on their first run — which is the
part worth recording. See [SWEEP-REPORT.md §4](../SWEEP-REPORT.md).

## Raised by the contract audit

| id | severity | title | status |
|:---:|:---:|---|---|
| [`S1`](S1-unpriced-forfeit.md) | Low | An unpriced holding could be forfeited with no value test | **Fixed** `1c128f2` / `e13841f` |

`S1` is off-chain — it is in the dust sweep's planner, not the router
application. It is here rather than filed away because it is the finding the
previous audit marked "verified safe", and because its severity is misleading:
the *action* requires an explicit user tick, but the *value* it could give away
is unbounded. Live data showed an asset worth 245.88 ALGO on that path.

[`S4`](S4-forfeit-lacks-evaluation-veto.md) completes it: the veto `S1` added
guards the branch requiring a tick, and not the branch that needs none.

## Closed, from v1–v5

Each was re-verified against the source at revision `8d130d6` rather than taken
from the earlier reports. The command for each is in
[../verification/verify.sh](../verification/verify.sh).

| id | severity | title | closed by |
|:---:|:---:|---|---|
| `C1` | Critical | Permissionless `convert_and_distribute` drained accrued fees | admin gate; pool from state; `_assert_no_conversion_pool_approval` |
| `H1` | High | Frontend-controlled floor permitted a zero-floor trade | floor removed from the signature; `_signed_floor` reads a co-signed note |
| `M1` | Medium | Route paths not checked for repeated assets | pairwise-distinct assertions |
| `M2` | Medium | Funding transaction adjacency not enforced | `payment.group_index + 1 == Txn.group_index` |
| `M3` | Medium | Pre-held ASA input not proven spent | `_assert_input_spent` |
| `M4` | Medium | Caller could name any pool application | Pact/STAMM pinned by `app_creator`; AlgoFi whitelisted; Tinyman derived |
| `M5` | Medium | Caller could request unbounded STAMM opups | `<= MAX_STAMM_OPUPS`; `== 0` for non-STAMM |
| `M6` | Medium | Conversion pool approved and used in one group | `_assert_no_conversion_pool_approval` |
| `M7` | Medium | MWPT asymmetric weight quoting drift | exact off-chain math |
| `L1` | Low | Deletion did not check asset holdings | holdings and accrued both checked |
| `L2` | Low | Administrative setters accepted the zero address | rejected |
| `L3` | Low | Reentrancy guard | structurally safe — no re-entrant path exists |
| `L4` | Low | Conversion minimum output unbounded | floor bounded |
| `L5` | Low | Voucher signer rotation | admin-rotatable; messages bound to app and sender |
| `L6` | Low | MWPT zero-output branch | handled |
| `L7` | Low | MWPT vault was implicit | read on-chain from the pool's global state |
| `I1` | Info | Liquid staking rate oracle boundary | real pools first, rate as fallback; quoter-side only |
| `I2` | Info | Dust sweep classification policy | → became [`S1`](S1-unpriced-forfeit.md) |
| `I3` | Info | Dead code for non-STAMM opups | removed |
| `I4` | Info | Dynamic minimum balance | handled |
| `I5` | Info | Unbound admin conversion batch repetition | accepted by design — admin-only |
| `I6` | Info | STAMM multi-tier ABI alignment | verified |
| `I7` | Info | AlgoFi defunct pool curation | accepted by design — see the maintenance note in [REPORT.md §5](../REPORT.md) |

## A note on `I2`

v5 issued it as "VERIFIED SAFE". It was not, and the re-examination that turned
it into `S1` is the single strongest argument for the method described in
[../methodology/README.md](../methodology/README.md): the finding was closed on
the strength of a test name, and the predicate that decided it had never been
read.
