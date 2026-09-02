# What the contract actually did

Seven groups that executed on Algorand mainnet on **2026-08-31**, inside one
ten-minute session, for a caller who is not the router's admin. 97 top-level
transactions and 183 inner ones, kept here exactly as the indexer returned
them.

**This is the first time any audit in this series has checked a claim against a
running system.** The five before it, and the source-reading half of this one,
answer *does the code say this?* — 123 checks across
[verify.sh](../verification/verify.sh) and
[verify-sweep.sh](../verification/verify-sweep.sh) that read
`router_app.py`, the sweep planner and the browser control. Nothing in either
answers *did the chain do this?*, and the two errors that did this series the
most damage were both facts about a running system:

- **v4** recommended lifting `RESTRICT_TO_ADMIN` because "mainnet has been
  running unrestricted for months". Mainnet was the restricted one.
- **v5** recorded the removal as already delivered. It had not happened.

Neither claim is refutable by reading a contract. Both are refutable by one
group that executed. That is what this directory is.

```sh
python3 ../verification/verify-groups.py                # 58 checks, no node
ALGOD_URL=… ALGOD_TOKEN=… python3 ../verification/verify-groups.py   # 63
```

Recorded output: [GROUP-RESULTS.md](../verification/GROUP-RESULTS.md).

---

## 1. What executed

| file | round | what it is |
|---|---|---|
| [`swap.json`](groups/swap.json) | 64591388 | a four-way split, USDC → ASASTATS, through three venues |
| [`sweep-1-closeout.json`](groups/sweep-1-closeout.json) | 64591415 | sixteen empty holdings closed to self |
| [`sweep-2-closeout.json`](groups/sweep-2-closeout.json) | 64591422 | sixteen more |
| [`sweep-3-convert.json`](groups/sweep-3-convert.json) | 64591445 | COOP → ASASTATS, four routes |
| [`sweep-4-convert.json`](groups/sweep-4-convert.json) | 64591454 | Algo69 → ASASTATS, three routes, two of which never touch ALGO |
| [`sweep-5-forfeit.json`](groups/sweep-5-forfeit.json) | 64591458 | nine close-outs and **six forfeits** |
| [`sweep-6-convert.json`](groups/sweep-6-convert.json) | 64591609 | tALGO → ASASTATS, three routes **and one direct pool leg** |

Plus [`account.json`](account.json), the caller's account read at round
64620255 — which is what makes the sweep's arithmetic checkable rather than
merely plausible.

Everything here is public chain state. Each transaction id resolves in any
explorer, and nothing in these files was written by this repository.

## 2. The deployment they ran against, and what that changes

Every application call in all seven groups names **`3689591968`**. The
retired `3688554446` — the application this repository's first revision audited
and described as "restricted to admin" — appears nowhere, and answers 404.

**The caller is `VW55KZ3N…K3CBSU`. The admin is `ZRNRW3X4…SLMQPM`.** Four of
these groups executed `route` and `route3` from an account that is not the
admin, which is the direct evidence that `RESTRICT_TO_ADMIN` is off on the
running program. The manifest says the same
(`"restrict_to_admin": false`); the chain is the half that cannot be edited.

So the sentence this repository opened with on 2026-08-30 — *the mainnet
deployment is restricted to its admin* — stopped being true the same day, and
[REPORT.md](../REPORT.md) now says so. The audit's position has not changed and
is not softened by the deployment happening: what replaces the restriction is
`set_paused`, which was pressed on mainnet before it was trusted, and the group
fee bound. See [contracts/going-unrestricted.md](../contracts/going-unrestricted.md).

Worth noting because it is the sort of thing a source-only audit gets wrong:
the caller's account is **rekeyed**. Every transaction carries
`auth-addr: HGFQY4KQ…3OVLDU`, and nothing in the group disturbs it — the
hygiene guard refuses a rekey *set*, and being already rekeyed is a different
thing. It also broke one of this repository's own scripts; see §10.

## 3. `H1` — the co-signed floor, and whether it bound

`H1` was the High from v1: a frontend could pass `minimum_received = 0`. The
fix removed the floor from the method signature and put it in the note of a
`pool_budget` call that only `quote_signer` can send.

All four routed groups carry exactly one such call — 192 bytes, sender
`STATS7ES…GXORJY`, **fee zero** — and its layout decodes exactly as
`Router._signed_floor` reads it:

| group | floor | received | over |
|---|---:|---:|---:|
| `swap` | 10,916,395,835 | 10,971,093,673 | +0.501% |
| `sweep-3` | 4,741,776,766 | 4,787,285,941 | +0.960% |
| `sweep-4` | 1,101,430,935 | 1,112,064,251 | +0.965% |
| `sweep-6` | 2,620,214,551 | 2,633,381,451 | +0.503% |

Two further things the note asserts, both checked here against the group rather
than against the source:

**Every named input index is a router call funded by the transaction
immediately before it.** That is `M2` — funding adjacency — observed rather
than asserted. Fourteen route calls across four groups, fourteen matches.

**The asserting index is the last route call, every time.** Only the last call
sees the whole group's output, so naming an earlier one would let the rest of
the split be trimmed away and the floor still met. Checked by finding the route
calls independently and comparing.

## 4. The four properties `REPORT` §2 rests on

Two of them a trace can settle outright.

**Inner transactions pay no fee.** All **183** of them, at every nesting depth,
carry `fee: 0`. The group's fee is pooled onto the caller's own transactions.
The application's balance cannot be drained by routing it.

**Inventory is transient.** In every group, every holding the contract opened
it also closed before the group ended — visible as a zero-amount self transfer
opening it and an inner transfer carrying `close-to` shutting it. Nothing was
left open, so no minimum balance was left locked.

The other two — output measured rather than trusted, and the floor being
co-signed — are a contract-internal control and a note layout. §3 covers the
second. The first is not observable from a trace and is not claimed here.

**Group hygiene** is observable, and holds: no transaction in any of the seven
groups sets `rekey-to` or `close-remainder-to`, and no top-level `asset-close-to`
appears in any group that carries a router call. The sweep's close-outs live in
groups that carry no application call at all, which is exactly the separation
`_assert_group_is_clean` forces and the reason the sweep needed a browser
control of its own.

## 5. `M4` and `M5` — the pools, and the opcode budget

Nine distinct pool applications were called across the seven groups. Each is
authenticated by the mechanism the contract compiles in, checked against the
chain:

| application | how it is pinned | creator |
|---|---|---|
| `1002541853` | `TINYMAN_V2_APP_ID` template | — |
| `2966799501`, `2757667443`, `3083570226`, `2960965065` | `PACT_POOL_CREATORS` | `E5QGPA7L…SJBEMM` |
| `2661867879` | `PACT_POOL_CREATORS` | `PACTFIIF…LCWP7I` |
| `3544791001` | `STAMM_POOL_CREATORS` | `46FAE637…OY6KJQ` |
| `3544641082`, `3544641019` | `STAMM_BUDGET_APP_ID` / `STAMM_OPUP_APP_ID` | — |

Two Pact creator generations in one session, which is the case the whitelist
exists for. Nothing reached a pool outside it.

`M5` bounded STAMM opups at `MAX_STAMM_OPUPS = 8`. Two STAMM legs ran here,
each issuing **exactly eight** inner calls, all of them to
`STAMM_OPUP_APP_ID` and nothing else.

## 6. `S3` — the fee bound, now that it is deployed

`3689591968` was compiled with `MAX_GROUP_FEE = 1_000_000`, so the half of
`S3` that this repository recorded as "source-only until the contract is
redeployed" is now live. What the session paid:

```
dearest group          71,000 microALGO      7.1% of the ceiling
every close-out fee     1,000 microALGO      MAX_CLOSE_OUT_FEE is 10,000
largest group              16 transactions   the limit is 16
```

Both widget rules bind with room, twice at the group-size limit exactly.

The chain-side finding is **unchanged and still true**: a close-out group
carries no application call, so `_assert_group_is_clean` never sees it, and
mainnet still accepts one whose fees consume the signer's whole spendable
balance. `verify-sweep.sh` re-simulates that on every run. The bound that
protects a close-out is the widget's, and it is the only one there is.

## 7. `S2` — where the six forfeits went

`sweep-5` is the only group in this evidence that gives anything away. Nine of
its fifteen transactions close empty holdings back to the caller; six close
**non-empty** holdings to somebody else. Resolved against the chain:

| asset | | closed | destination is the creator |
|---|---|---:|---|
| `388502764` | SVANSY | 1,000,000,000 | ✓ |
| `607591690` | XGLI | 90,000,000 | ✓ |
| `792313023` | xSOL | 596,815 | ✓ |
| `310014962` | ALCH | 25 | ✓ |
| `27165954` | PLANET | 50,000,000 | ✓ |
| `417708610` | DEGEN | 500 | ✓ |

Six for six. This is the control `S2` added, doing the thing `S2` said it
must: the destination is compared against the asset's creator **read from the
chain**, not against `holdings[].creator` in the response being checked. Redirect
one of these in the evidence and the check fails — that mutation is one of six
run against this verifier.

What it does **not** show is that these six were worth forfeiting. That is
`S1` and `S4`, and it needs an account evaluation from the same moment, which
is not in this evidence. See §9.

## 8. The fee schedule, recomputed rather than quoted

`set_fee` was moved to 5 bps on the same day this application was deployed —
the first time the rate has ever been charged to somebody who is not the
admin. Every `accrued` delta in the session was recomputed from the transfers
around it:

```
every fee taken is exactly floor(ALGO leg × 5 / 10000)      no exceptions
accrued across the whole session          1,529 microALGO
network fees over the same session      280,000 microALGO   183× the platform's cut
```

**Two route calls paid nothing at all**, and that is correct rather than a
leak. `_skim`'s docstring says it is "only ever called on ALGO, which is what
keeps the escrows free of per-asset opt-ins and the treasury free of a price
oracle" — so a route whose every hop is ASA-to-ASA accrues nothing. Both of
`sweep-4`'s later routes are that shape (Algo69 → Busk → Drop → ASASTATS, and
Algo69 → Busk → tALGO → ASASTATS), and both moved real value for free.

That is a revenue observation, not a security one — it under-charges the
operator and never the user. It is recorded because it is invisible in the
source unless you already know to look for a route with no ALGO hop, and
obvious the moment you total the state deltas.

## 9. What the sweep left behind

47 holdings closed, 4.7 ALGO of minimum balance released, 0.28 ALGO of network
fees. None of the 47 is still opted in. Eleven empty holdings were left alone,
and reading what they are is the best available live test of the dApp-position
filter:

- **eight are NFTs** — collection members the evaluation lists under
  `nftcollections`. Excluded unconditionally, which is the rule.
- **`760037151` (xUSD) and `2400334372` (cAlgo)** hold **zero on chain** and
  are not empty at all: the evaluation shows 1,000,000 xUSD in a CompX staking
  program and 136,623,993 cAlgo in a Tinyman v2 LP position. Neither carries a
  `Balance` program, so the filter disqualifies the asset — and closing either
  holding would strand a position its owner still has to withdraw. This is the
  filter earning its keep, on live data, in the one case where "the holding is
  empty" and "the user has nothing here" come apart.
- **`242345487` (AB2 Gallery Flag)** is in neither list. It is not in the
  evaluation at all, so the planner never sees it. See below.

## 10. Three things the trace surfaced that reading had not

Recorded separately because they are the argument for doing this at all.

### A direct pool leg sits outside the co-signed floor

`sweep-6` is not four router calls. It is **three router calls and one
transfer straight into a Tinyman v2 pool**, in the same atomic group, and the
direct leg carries 63% of the input. That is by design — `route_transactions`
returns ungrouped transactions precisely "so that a route can be concatenated
with direct legs the allocator also chose" — and it is not a defect.

But it means the guarantee `H1` bought does not cover the whole group. The
co-signed note's floor is `2,620,214,551`, and the router legs delivered
`2,633,381,451` against it; the direct leg's own minimum, `4,281,103,010`, sits
in Tinyman's `application-args`, **written by the same client the co-signed
floor exists to distrust**. A compromised frontend has nowhere to put a zero on
three of these four legs and a perfectly ordinary place to put one on the
fourth.

Nothing was lost here — the direct leg cleared its own floor by 0.50%, the same
tolerance as the rest — and the exposure is bounded by the share the allocator
sends direct rather than by the whole order. It is recorded as a **boundary of
the audited control surface**, not as a finding: `REPORT` §2 says "a
compromised frontend has nowhere to put a zero", and on a group shaped like
this one, that sentence is true of the router's part and not of the group.

### A holding the evaluation does not list is invisible to the sweep

`242345487` has been opted in, holds nothing, and appears in neither
`asaitems` nor `nftcollections`. The planner works from the evaluation, so it
cannot propose closing something the evaluation does not mention.

Failing that way round is right — `S1` is what happens when the planner acts
on a holding it cannot value — but it is silent. The row never appears, so the
user cannot ask why 0.1 ALGO is still locked. Worth a line in the interface
rather than a finding.

### This repository's own script gave a false answer, and it took a second account to find it

`verify-sweep.sh` simulates a close-out with an absurd fee to show that the
chain bounds it only by the balance. Pointed at this account it reported
`refused`, and the check failed.

The fee had nothing to do with it. The account is rekeyed, and a simulate with
`allow-empty-signatures` and no `sgnr` is refused for **authorisation**:

```
should have been authorized by HGFQY4KQ… but was actually authorized by VW55KZ3N…
```

`refused` is what a working bound looks like. The script reported the right
word for the wrong reason, and would have gone on reporting it. Fixed by
carrying the account's `auth-addr` into the simulated signature; with that,
`fee = the entire spendable balance` is accepted again and the finding stands.

The bug could not appear on the account the original run used, because that one
was not rekeyed. **A check that has only ever been run against one fixture has
been tested about as well as the code it is checking** — which is this
repository's own thesis, arriving from the other direction.

## 11. What this evidence does not show

Stated plainly, because a trace is unusually good at looking like proof of
more than it is.

- **It is one session, one caller, one account.** Seven groups that worked. It
  says nothing about what the contract refuses, and refusals are most of the
  security case. Every negative claim in [REPORT.md](../REPORT.md) still rests
  on source and on simulate.
- **It cannot show that a control fired**, only that nothing needed it to. No
  group here carries a rekey for the guard to catch, an over-budget opup request
  for `M5` to refuse, or a mispriced holding for `disputed_dust` to veto.
- **It cannot value the forfeits.** Six holdings were given away; whether any
  was worth keeping needs the account evaluation from that moment, which is not
  here. `S1` and `S4` remain argued from source, from the measured divergence in
  [SWEEP-REPORT §6](../SWEEP-REPORT.md), and from the xALGO/tALGO incident.
- **It is not adversarial.** Nobody attacked this group. A trace of successful
  operation is the weakest kind of evidence about a hostile one, and the
  strongest available about what the deployment *is*.

The honest summary: this settles facts about the running system that source
cannot, and settles nothing about behaviour nobody provoked.
