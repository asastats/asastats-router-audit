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

**Most of these assert the fixed behaviour.** The first revision of this script
asserted the defects and passed 23 of 23, which was the finding. `S2`–`S7` are
closed, so each of those checks is now the regression test for one of them.

**The `S8` section is the exception, and deliberately.** That finding is open,
so its checks assert the gap: two of them run the vector against the shipped
widget and require it to be **accepted**. The day a fix lands they fail, and
that failure is how the finding gets closed rather than forgotten.

**One check was itself wrong, and a second account is what found it.** The
simulate that shows the chain bounding a fee only by the balance did not set
`sgnr`, so against a *rekeyed* account it was refused for authorisation and
reported `refused` — the right word for the wrong reason, indistinguishable
from the bound working. Fixed by carrying the account's `auth-addr` into the
simulated signature. See [evidence/README.md §10](../evidence/README.md).

```
router:   68ad254   (contract deployed as mainnet 3689591968 from 848a3a3)
engine:   1616efc
frontend: 0c8600b
widgets:  4fe081b   (S6/S7 fixes merged to dust-sweep, not yet released)
date:     2026-09-01
network:  mainnet, account 2EVGZ4BG…GXNSIU
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
  PASS  the hygiene guard now totals the group's fee             1
  PASS  ...and refuses a group that overpays                     1
  PASS  the ceiling clears the dearest route route_fee can return clears

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

Before RESTRICT_TO_ADMIN comes off — the two levers that replace it
-------------------------------------------------------------------------
  PASS  routing can be stopped without a redeploy                1
  PASS  both route entry points honour the pause                 2
  PASS  the pause is admin-only                                  1
  PASS  close_holding is NOT paused, so recovery survives it     0
  PASS  no input cap, which could not have meant one thing       0
  PASS  the contract carries three global uints                  3
  PASS  the test harness takes the schema from the compiler      1
  PASS  no fixture pins a schema by hand any more                0
  PASS  15 entry points, 13 walking the group, 2 inert           15/13/pool_budget,verify_discount

S5 — does a malformed payload degrade rather than raise?
-------------------------------------------------------------------------
  PASS  the evaluation readers share one shape-tolerant reader   2
  PASS  the browser checks share one too                         2
  PASS  neither python reader raises on any shape                degrades
  PASS  neither browser check raises on any shape                degrades

S6 — is the conversion path checked at all?
-------------------------------------------------------------------------
  PASS  signAction dispatches on the engine's own action.kind    1
  PASS  ...and its convert branch no longer trusts it            1
  PASS  the browser mirrors the contract's three hygiene fields  3
  PASS  ...and the contract's group fee ceiling, by its number   1
  PASS  which is the number the contract actually uses           1
  PASS  a group that will not decode is refused, not skipped     2
  PASS  the hygiene guard refuses closes, when it runs           2
  PASS  signAndSendPartial checks quote placement and signatures 3

S7 — does the conversion path require the checks to actually run?
-------------------------------------------------------------------------
  PASS  a conversion must call a router method that guards       1
  PASS  the app id is page context, never the plan response      1
  PASS  ...handed down by the view, not read from the engine     1
  PASS  ...and the widget carries the same id as a fallback      2
  PASS  which is the application the audit pins to mainnet       1
  PASS  the exempt selectors are both excluded                   2
  PASS  ...and they are the selectors the contract actually exposes ok

S8 — what still gets through, and why the obvious rule cannot be it (OPEN)
-------------------------------------------------------------------------
  PASS  the route binds only the transaction before it           1
  PASS  the hygiene guard reads no amount and no receiver        0
  PASS  and the browser bounds no receiver either                0
  PASS  a conversion that executed pays a non-router address     1
  PASS  a genuine conversion is accepted                         accepted
  PASS  ...and so is the same group carrying a hostile transfer  accepted
  PASS  the quote signer key is read in the engine's own process 2
  PASS  ...from a path on the engine's own host                  2
  PASS  ...and it validates group ids, not group composition     0
  PASS  a creator lookup that never answers times out            1
  PASS  ...and a timeout resolves to null, so it joins the refusals 1

context
-------------------------------------------------------------------------
  PASS  the asset cache is consulted before the node by default  1
  PASS  forfeit is included by default; unpriced is not          1
  PASS  unpriced is the only disposition that starts off         1

-------------------------------------------------------------------------
  68 passed, 0 failed, 0 skipped

```
