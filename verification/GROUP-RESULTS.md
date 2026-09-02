# Recorded verification run — the executed groups

Output of `verify-groups.py` against [evidence/](../evidence/). Re-run it
yourself:

```
python3 verify-groups.py                                     # offline
ALGOD_URL=http://127.0.0.1:8085 ALGOD_TOKEN=… \
    python3 verify-groups.py                                 # with a node
```

```
evidence: /home/ipaleka/claude/asastats-router-audit/evidence
groups:   7
node:     <mainnet-algod>


the deployment these groups ran against
-------------------------------------------------------------------------
  PASS  the applications these groups call at top level            [1002541853, 3689591968]
  PASS  so every router call names 3689591968, not the retired 3688554446 True
  PASS  the caller is not the admin, so RESTRICT_TO_ADMIN is off   True
  PASS  the caller's account is rekeyed, which the group does not disturb HGFQY4KQULWHTHCSM7A2YBWC3B3NXN36ZDBPUYYD4TAOONRH7SY63OVLDU
  PASS  the retired application really is gone                     404
  PASS  and the live one carries the `paused` key set_paused added True
  PASS  the application the evidence called is retired too         404

H1 - the floor is co-signed, and it bound
-------------------------------------------------------------------------
  PASS  groups carrying a router call                              4
  PASS  swap.json: exactly one co-signed floor                     1
  PASS  swap.json: the note names this application and this caller True
  PASS  swap.json: the quote signer pays no fee of its own         0
  PASS  swap.json: received >= the signed floor                    True
        floor 10,916,395,835   received 10,971,093,673   +0.501%
  PASS  swap.json: the note names at least one funded input        True
  PASS  swap.json: every named input is funded by the transaction before it True
  PASS  swap.json: the asserting index is the last route call      11
  PASS  sweep-3-convert.json: exactly one co-signed floor          1
  PASS  sweep-3-convert.json: the note names this application and this caller True
  PASS  sweep-3-convert.json: the quote signer pays no fee of its own 0
  PASS  sweep-3-convert.json: received >= the signed floor         True
        floor  4,741,776,766   received  4,787,285,941   +0.960%
  PASS  sweep-3-convert.json: the note names at least one funded input True
  PASS  sweep-3-convert.json: every named input is funded by the transaction before it True
  PASS  sweep-3-convert.json: the asserting index is the last route call 11
  PASS  sweep-4-convert.json: exactly one co-signed floor          1
  PASS  sweep-4-convert.json: the note names this application and this caller True
  PASS  sweep-4-convert.json: the quote signer pays no fee of its own 0
  PASS  sweep-4-convert.json: received >= the signed floor         True
        floor  1,101,430,935   received  1,112,064,251   +0.965%
  PASS  sweep-4-convert.json: the note names at least one funded input True
  PASS  sweep-4-convert.json: every named input is funded by the transaction before it True
  PASS  sweep-4-convert.json: the asserting index is the last route call 8
  PASS  sweep-6-convert.json: exactly one co-signed floor          1
  PASS  sweep-6-convert.json: the note names this application and this caller True
  PASS  sweep-6-convert.json: the quote signer pays no fee of its own 0
  PASS  sweep-6-convert.json: received >= the signed floor         True
        floor  2,620,214,551   received  2,633,381,451   +0.503%
  PASS  sweep-6-convert.json: the note names at least one funded input True
  PASS  sweep-6-convert.json: every named input is funded by the transaction before it True
  PASS  sweep-6-convert.json: the asserting index is the last route call 10

the four properties REPORT section 2 rests on
-------------------------------------------------------------------------
  PASS  inner transactions sent by the contract                    183
  PASS  every one of them pays a zero fee                          True
  PASS  every holding the router opened, it closed in the same group True

group hygiene - _assert_group_is_clean, on chain
-------------------------------------------------------------------------
  PASS  the rekey detector fires on a transaction that rekeys      True
  PASS  the ALGO-close detector fires on a transaction that closes True
  PASS  transactions examined for both                             280
  PASS  no transaction in any group rekeys an account              True
  PASS  no transaction in any group closes an ALGO balance         True
  PASS  a close-out never rides in the same group as a route       []

M4 - every pool the contract called is one it authenticates
-------------------------------------------------------------------------
  PASS  distinct pool applications called                          9
  PASS  each is pinned by app id or by its creator on chain        []

M5 - the STAMM opcode budget is bounded
-------------------------------------------------------------------------
  PASS  STAMM budget calls in this evidence                        2
  PASS  none issues more than MAX_STAMM_OPUPS (8)                  True
  PASS  and every one of those is an opup call, not something else True

S3 - the fee, now that the contract half is deployed
-------------------------------------------------------------------------
  PASS  the dearest group's total fee is under MAX_GROUP_FEE (1,000,000) True
        dearest group 71,000 microALGO, 7.1% of the ceiling
  PASS  every close-out's fee is at or under MAX_CLOSE_OUT_FEE (10,000) True
  PASS  no group exceeds the sixteen-transaction limit             True

the fee schedule, recomputed from the state deltas
-------------------------------------------------------------------------
  PASS  every fee taken is exactly floor(ALGO leg x 5 / 10000)     []
  PASS  routes with no ALGO leg accrued nothing, as _skim's docstring says True
        2 route call(s) never touched ALGO and paid no platform fee
        accrued across the whole session: 1,529 microALGO
        network fees over the same session: 280,000 microALGO (183x the platform's cut)
  PASS  route calls that took a fee, so there is a rate to check   True
  PASS  the rate actually charged never exceeded MAX_FEE_BPS (100) True
        dearest rate observed: 4.9913 bps over 12 fee(s)

S2 - every forfeit went to the asset's creator
-------------------------------------------------------------------------
  PASS  forfeits in the evidence                                   6
  PASS  each closes a non-empty holding, which is what a forfeit is True
  PASS  the chain agrees the destination is the creator            []

the sweep reconciles against the account it swept
-------------------------------------------------------------------------
  PASS  distinct holdings closed                                   47
  PASS  none of them is still opted in                             set()
  PASS  the account holds what is left                             65
        11 empty holdings the sweep left alone: [242345487, 492076550, 580840585, 601272774, 733125420, 760037151, 835925181, 839128313, 885669559, 885670439, 2400334372]
        minimum balance released: 4,700,000 microALGO against 280,000 in fees

-------------------------------------------------------------------------
  63 passed, 0 failed, 0 skipped

```
