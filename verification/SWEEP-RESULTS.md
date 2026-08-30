# Recorded verification run — dust sweep

Output of `./verify-sweep.sh` on the revisions named below. Re-run it yourself:

```
ROUTER=/path/to/router WIDGETS=/path/to/widgets ENGINE=/path/to/engine \
ALGOD_URL=https://your-node SWEEP_ADDRESS=SOMEADDRESS… \
    ./verify-sweep.sh
```

Four checks need a mainnet algod. Without `ALGOD_URL` and `SWEEP_ADDRESS` they
report `SKIP`; the run below had both, so nothing was skipped. Nothing is
submitted — the chain cases use `simulate` with `allow-empty-signatures` and no
key.

```
router:   8d130d6
engine:   1b2c588
frontend: 2904746
widgets:  4b4eec8
date:     2026-08-30
network:  mainnet, account OGRUNXPS…2CEN2M (31.688265 ALGO, 3 empty holdings)
```

```
S2 — does the whitelist bind the forfeit destination?
-----------------------------------------------------
  PASS  an honest forfeit is accepted                            accepted
  PASS  a forfeit to an attacker, consistently described         accepted
  PASS  bytes and description disagreeing is refused             refused
  PASS  expected[] is built from the plan's own holdings         1
  PASS  Django forwards the engine answer verbatim               1

S3 — is the fee bounded anywhere?
-----------------------------------------------------
  PASS  closeOutProblems never reads txn.fee                     0
  PASS  a close-out with a 5 ALGO fee passes the whitelist       accepted
  PASS  the group hygiene guard checks three fields, none a fee  3
  PASS  the contract's hygiene guard never mentions fee          0
  PASS  summaryFigures renders no fee                            0
  PASS  summary.recoverable is gross of fees                     1

S3 — what would the chain accept? (needs a node)
-----------------------------------------------------
  PASS  the chain takes the minimum fee                          accepted
  PASS  the chain takes 0.1 ALGO, cancelling what a close recovers accepted
  PASS  the chain takes the entire spendable balance as a fee    accepted
  PASS  a close-out carrying asnd is refused by the chain        refused

S4 — does the evaluation veto reach the forfeit branch?
-----------------------------------------------------
  PASS  priced_elsewhere has exactly one consumer                1
  PASS  ...and it is inside the UNPRICED branch                  1
  PASS  the FORFEIT branch tests nothing but the disposition     1
  PASS  no router price: unpriced, and not swept by default      unpriced:safe
  PASS  wrong small price: forfeit, swept with no user action    forfeit:swept

context
-----------------------------------------------------
  PASS  the asset cache is consulted before the node by default  1
  PASS  forfeit is included by default; unpriced is not          1
  PASS  unpriced is the only disposition that starts off         1

-----------------------------------------------------
  23 passed, 0 failed, 0 skipped
```

## Reading the S2 block

The three `accepted` results are not a clean bill of health — they are the
finding. A group closing a holding to an arbitrary address is accepted whenever
the description accompanying it names that same address, and only the fourth
case, where the two disagree, is refused. That is what
[`S2`](../findings/S2-forfeit-target-self-certifying.md) says the control does.

## The field-coverage derivation

Not a pass/fail check, so it is recorded here rather than in the script's
output. Produced by parsing `closeOutProblems` for `txn.<field>` and building
an `axfer` carrying every optional field:

```
inspected by closeOutProblems (7): aamt aclose arcv rekey snd type xaid
carried by an honest close-out (10): aclose arcv fee fv gen gh lv snd type xaid
possible on an axfer (15): aamt aclose arcv asnd fee fv gen gh lv lx note rekey snd type xaid

never inspected: asnd fee fv gen gh lv lx note
```

Of the eight: `fee` is [`S3`](../findings/S3-unbounded-fee.md); `asnd` is
refused by the chain when `aclose` is set, verified above; `fv`/`lv`/`gen`/`gh`
can only make a transaction invalid rather than more damaging; `lx` (lease) and
`note` are minor — a hostile lease could block the sender's own transactions
for the validity window, and a note publishes arbitrary bytes under the user's
signature. Neither moves value, and both are noted rather than filed.

## Test suites at this revision

```
router/tests/test_sweep.py         123 collected
engine/core/tests/test_sweep.py     62 collected
dustsweep jest                     121 passed, 100% line and branch coverage
```

All three findings survive that coverage. See
[SWEEP-REPORT.md §4](../SWEEP-REPORT.md).
