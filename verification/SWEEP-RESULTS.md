# Recorded verification run — dust sweep

Output of `./verify-sweep.sh` on the revisions named below. Re-run it yourself:

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
  PASS  the shipped wallet bundle exposes assetCreator           yes

S3 — is the fee bounded?
-------------------------------------------------------------------------
  PASS  closeOutProblems reads txn.fee                           2
  PASS  a close-out with a 5 ALGO fee is refused                 refused
  PASS  the cap is a fraction of what a close-out returns        1
  PASS  summaryFigures renders the fee                           1
  PASS  summary.recoverable is net of fees                       1
  PASS  the hygiene guard is there to be read                    1
  PASS  the hygiene guard still checks rekey_to                  1
  PASS  the hygiene guard still checks close_remainder_to        1
  PASS  the hygiene guard still checks asset_close_to            1
  PASS  the hygiene guard now totals the group's fee             1
  PASS  ...and refuses a group that overpays                     1
  PASS  the ceiling clears the dearest route route_fee can return clears

S3 — what the chain would accept, unchanged by any fix (needs a node)
-------------------------------------------------------------------------
  PASS  the chain itself still bounds a fee only by the balance  accepted
  PASS  a close-out carrying asnd is refused by the chain        refused
  PASS  ...and refused for carrying asnd, not for anything else  yes
        chain said: cannot close asset by clawback

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
  PASS  close_holding is there to be checked                     1
  PASS  close_holding is NOT paused, so recovery survives it     0
  PASS  no input cap, which could not have meant one thing       0
  PASS  __init__ is there to be counted                          1
  PASS  the contract carries three global uints                  3
  PASS  the test harness takes the schema from the compiler      1
  PASS  no fixture pins a schema by hand any more                0
  PASS  15 entry points, 13 walking the group, 2 inert           15/13/pool_budget,verify_discount

S5 — does a malformed payload degrade rather than raise?
-------------------------------------------------------------------------
  PASS  the evaluation readers share one shape-tolerant reader   3
  PASS  the browser checks share one too                         3
  PASS  neither python reader raises on any shape                degrades
  PASS  neither browser check raises on any shape                degrades

S6 — is the conversion path checked at all?
-------------------------------------------------------------------------
  PASS  signAction dispatches on the engine's own action.kind    1
  PASS  ...and its convert branch no longer trusts it            1
  PASS  routedGroupProblems is there to be read                  1
  PASS  the browser mirrors the contract's rekey field           1
  PASS  the browser mirrors the contract's close field           1
  PASS  the browser mirrors the contract's aclose field          1
  PASS  ...and the contract's group fee ceiling, by its number   1
  PASS  which is the number the contract actually uses           1
  PASS  a group that will not decode is refused, not skipped     2
  PASS  the hygiene guard refuses closes, when it runs           2
  PASS  signAndSendPartial is there to be read                   1
  PASS  signAndSendPartial checks quote placement                1
  PASS  signAndSendPartial checks the signature matches          1
  PASS  signAndSendPartial checks the signature is present       1

S7 — does the conversion path require the checks to actually run?
-------------------------------------------------------------------------
  PASS  a conversion must call a router method that guards       1
  PASS  the app id is page context, never the plan response      1
  PASS  ...handed down by the view, not read from the engine     1
  PASS  ...and the widget carries the same id as a fallback      1
  PASS  ...as does the view that hands it down                   1
  PASS  which is the application the audit pins to mainnet       1
  PASS  the exempt selectors are both excluded                   2
  PASS  ...and they are the selectors the contract actually exposes ok

S8 — the browser cannot bound this, and the signer now does (FIXED)
-------------------------------------------------------------------------
  PASS  the route binds only the transaction before it           1
  PASS  the hygiene guard is still the thing being read          1
  PASS  the hygiene guard reads no amount and no receiver        0
  PASS  routedGroupProblems is still the thing being read        1
  PASS  and the browser bounds no receiver either                0
  PASS  a conversion that executed pays a non-router address     1
  PASS  a genuine conversion is accepted                         accepted
  PASS  ...and the browser still accepts a hostile transfer beside it accepted
  PASS  the signer accepts the conversion that executed          accepted
  PASS  ...and refuses the same group carrying the hostile transfer refused
  PASS  the signer reads the whitelists the contract compiles in 1
  PASS  ...and the deploy script reads the same ones             1
  PASS  a destination is derived, never taken from the group     0
  PASS  the quote signer key is read in the engine's own process 2
  PASS  ...from a path on the engine's own host                  2
  PASS  _validate_group is there to be read                      1
  PASS  ...and it validates group ids, not group composition     0
  PASS  a creator lookup that never answers times out            1
  PASS  ...and a timeout resolves to null, so it joins the refusals 1

context
-------------------------------------------------------------------------
  PASS  the asset cache is consulted before the node by default  1
  PASS  forfeit is included by default; unpriced is not          1
  PASS  unpriced is the only disposition that starts off         1

-------------------------------------------------------------------------
  89 passed, 0 failed, 0 skipped
```
