# Recorded verification run — dust sweep

Output of `./verify-sweep.sh` on the revisions named below. Re-run it yourself:

```
ROUTER=/path/to/router WIDGETS=/path/to/widgets ENGINE=/path/to/engine \
ALGOD_URL=https://your-node SWEEP_ADDRESS=SOMEADDRESS… \
    ./verify-sweep.sh
```

Two checks need a mainnet algod. Without `ALGOD_URL` and `SWEEP_ADDRESS` they
report `SKIP`; the run below had both, so nothing was skipped. Nothing is
submitted — the chain cases use `simulate` with `allow-empty-signatures` and no
key.

**These assert the fixed behaviour.** The first revision of this script
asserted the defects and passed 23 of 23, which was the finding. `S2` and `S4`
are closed and `S3` is closed for close-out groups, so each check is now the
regression test for one of them.

```
router:   2aad22b   (audited at 8d130d6)
engine:   9320ae2   (audited at 1b2c588)
frontend: 199b9a0   (audited at 2904746)
widgets:  0be86c7   (audited at 4b4eec8)
date:     2026-08-30
network:  mainnet, account OGRUNXPS…2CEN2M (31.688265 ALGO, 3 empty holdings)
```

```
S2 — is the forfeit destination bound to something outside the response?
-------------------------------------------------------------------------
  PASS  an honest forfeit is accepted                            accepted
  PASS  the whitelist alone still cannot see a consistent lie    accepted
  PASS  bytes and description disagreeing is refused             refused
  PASS  the chain agreeing accepts the forfeit                   accepted
  PASS  the chain disagreeing refuses it                         refused
  PASS  a bridge that cannot answer refuses (fails closed)       refused
  PASS  an unreadable asset refuses (fails closed)               refused
  PASS  signAction runs the chain check too                      1
  PASS  the shipped wallet bundle exposes assetCreator           1

S3 — is the fee bounded?
-------------------------------------------------------------------------
  PASS  closeOutProblems reads txn.fee                           2
  PASS  a close-out with a 5 ALGO fee is refused                 refused
  PASS  the cap is a fraction of what a close-out returns        1
  PASS  summaryFigures renders the fee                           1
  PASS  summary.recoverable is net of fees                       1
  PASS  the contract's hygiene guard still checks its three fields 3

S3 — what the chain would accept, unchanged by any fix (needs a node)
-------------------------------------------------------------------------
  PASS  the chain itself still bounds a fee only by the balance  accepted
  PASS  a close-out carrying asnd is refused by the chain        refused

S4 — does a forfeit check the second opinion?
-------------------------------------------------------------------------
  PASS  classify consults disputed_dust                          1
  PASS  the engine carries the evaluation's value onto the holding 1
  PASS  no router price at all: still unpriced and still safe    unpriced:safe
  PASS  wrong small price the evaluation disputes: kept, not swept keep:safe
  PASS  both sources calling it dust: still forfeited            forfeit:swept
  PASS  evaluation with no opinion: still forfeited              forfeit:swept

context
-------------------------------------------------------------------------
  PASS  the asset cache is consulted before the node by default  1
  PASS  forfeit is included by default; unpriced is not          1
  PASS  unpriced is the only disposition that starts off         1

-------------------------------------------------------------------------
  26 passed, 0 failed, 0 skipped
```

## Reading the S2 block

**"the whitelist alone still cannot see a consistent lie" passes, and should.**
`closeOutProblems` compares the bytes against the plan, and a consistent plan
agrees with itself; that is the reason the chain check exists, not a defect in
the whitelist. The four `chain.*` checks are the fix: the creator is read from
the chain, a disagreement refuses, and both failure modes — a bridge that
cannot answer, an asset that cannot be read — refuse rather than pass.

The `assetCreator` check reaches across repositories on purpose. The widget's
control fails closed, so it refuses every forfeit until the wallet bundle
shipping alongside it actually exposes that method; a green check here is what
says the two are in step.

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

Before the fixes, and after:

```
router/tests/test_sweep.py         123 collected  ->  139 passed
engine/core/tests/test_sweep.py     62 collected  ->   64 passed
dustsweep jest                     121 passed     ->  137 passed
                                   100% line and branch, both times
```

All three findings survived the first column. That is the point of
[SWEEP-REPORT.md §4](../SWEEP-REPORT.md): coverage records which lines ran, not
which claims were tested.

Wider suites at the fixed revision: router 963 passed / 1 skipped, engine core
569 passed / 1 skipped, widgets 196 passed, wallet 101 passed.
