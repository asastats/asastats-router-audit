# Findings

27 in total across seven audits: 23 raised by v1–v5 and closed, one raised by
the contract audit, and three by the dust sweep audit.

## Open

**None in the contract.** Three off-chain, all in the dust sweep — see
[SWEEP-REPORT.md](../SWEEP-REPORT.md).

| id | severity | title |
|:---:|:---:|---|
| [`S2`](S2-forfeit-target-self-certifying.md) | Medium | The browser whitelist does not bind the forfeit destination |
| [`S3`](S3-unbounded-fee.md) | Medium | Nothing bounds the fee on a transaction the sweep asks a user to sign |
| [`S4`](S4-forfeit-lacks-evaluation-veto.md) | Medium | The evaluation veto guards the opt-in path but not the automatic one |

None is reachable by an unprivileged remote attacker: `S2` and `S3` need the
engine's response to be wrong, and `S4` needs only a wrong price. Each is rated
Medium because it defeats a control built specifically to hold under those
conditions, and because the value each exposes is unbounded.

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
