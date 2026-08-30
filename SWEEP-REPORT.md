# Dust Sweep — security audit

**Off-chain. This is not a contract audit.** The router application is not
involved in the operation examined here: a dust sweep's close-out groups carry
no application call, which is the whole reason they needed a control of their
own. For the contract, read [REPORT.md](REPORT.md).

- **Date:** 2026-08-30
- **Scope:** `widgets/inhouse/dustsweep/` (controller, view, tests),
  `router/sweep.py`, `router/selection.py`, `engine/core/sweep.py`, and the
  wallet bridge's `signAndSend`
- **Verification:** [verification/verify-sweep.sh](verification/verify-sweep.sh)
  — 33 checks, all passing, none skipped
- **Findings:** four — three Medium and one Informational, all fixed. One of
  the fixes is source-only until the contract is redeployed.

---

## 1. Why this subsystem gets its own audit

**The sweep is the only feature that gives a user's assets away.** Everything
else in the product moves value between a user's own accounts or quotes a trade
they initiate. A *forfeit* closes a holding to the asset's creator — the only
target the chain reliably accepts, since closing a non-empty holding to self is
refused and closing to a stranger needs them opted in — and the entire safety
case is that the holding is worth less than the 0.1 ALGO it locks.

The previous audit reviewed this area and marked its classification policy
"VERIFIED SAFE". Re-reading the predicate instead of the test name produced
[`S1`](findings/S1-unpriced-forfeit.md), a real defect, now fixed. This audit
read the rest with the same intent.

## 2. Findings

| id | severity | title | status |
|:---:|:---:|---|---|
| [`S2`](findings/S2-forfeit-target-self-certifying.md) | Medium | The browser whitelist does not bind the forfeit destination | **Fixed** |
| [`S3`](findings/S3-unbounded-fee.md) | Medium | Nothing bounds the fee on a transaction the sweep asks a user to sign | **Fixed** (contract half undeployed) |
| [`S4`](findings/S4-forfeit-lacks-evaluation-veto.md) | Medium | The evaluation veto guards the opt-in path but not the automatic one | **Fixed** |
| [`S5`](findings/S5-malformed-evaluation-raises.md) | Info | A malformed evaluation took the whole sweep down rather than degrading | **Fixed** |

The three Medium ones share a precondition worth stating plainly: **none was
reachable by an unprivileged remote attacker.** `S2` and `S3` need the engine's response to
be wrong — through code compromise, or through the Redis asset cache the engine
reads without checking. `S4` needs only a wrong price, which is a bug rather
than an adversary, and one of exactly that class occurred in production three
weeks ago.

They are rated Medium rather than Low because each defeats a control that was
built specifically to hold under those conditions, and because the value each
exposes is unbounded.

**What is not deployed.** `S3` is closed twice over — a cap in the widget for
close-out groups, and a fourth assertion in `_assert_group_is_clean` that
totals the fee across any routed group. The second is source-only: mainnet
`3688554446` and testnet `770123816` were compiled before it existed, so
every group they execute is still bounded by nothing but the signer's balance
until a deployment happens. See [`S3` §7](findings/S3-unbounded-fee.md).

### `S2` — the whitelist restates the engine where it matters most

The widget decodes every close-out group in the browser before it reaches the
wallet, on an explicitly stated principle:

> a control that consists of trusting the thing it is meant to check is not a
> control

Seven of its rules are anchored to the transaction's shape or to the wallet's
own active account, and those hold. One is not: the destination of a *forfeit*
is compared against `holdings[].creator` from **the same HTTP response** as the
bytes being checked. An engine that sets both consistently chooses where a
user's tokens go, and the check passes.

Demonstrated by running the shipped `closeOutProblems` against a group closing
to an arbitrary address, described as closing to that address: `accepted`. The
same bytes with an honest description: `refused`. What the control actually
catches is a response that contradicts itself.

The reader cannot compensate, because the row never shows the destination.

**Fixed** by resolving the creator from the chain through the wallet bridge's
own algod client and comparing the transaction against that, failing closed
when it cannot be read.

### `S3` — the fee is unbounded, and invisible

Deriving the field coverage mechanically rather than by eye: the whitelist
inspects 7 of the 15 fields an `axfer` can carry, and `fee` is not among them.
It is not bounded downstream either — `signAndSend` reassigns `group` and
leaves every other field alone — nor on the conversion path, where the
contract's `_assert_group_is_clean` tests `rekey_to`, `close_remainder_to` and
`asset_close_to`, and nothing else.

Simulated against mainnet on a real account: a fee of 0.1 ALGO is accepted,
which exactly cancels what a close-out recovers; a group of close-outs whose
fees total the account's entire spendable balance (28.27 ALGO) is accepted.
**The only bound is the account's spendable balance.**

The interface would not move. `summary.fees` is computed, sent to the browser,
and never rendered; the *You recover* figure is gross of fees.

**Fixed**, in both places it needed to be. Close-out fees are capped at a
tenth of what a close-out returns and the fee is shown beside what the sweep
recovers; `_assert_group_is_clean` totals the fee across any routed group and
refuses a total above `MAX_GROUP_FEE`, sized from the dearest route
`route_fee` can return rather than picked. The contract half awaits a
deployment.

### `S4` — the veto is on the branch that needs it less

`S1`'s fix refuses to forfeit an `UNPRICED` holding that the account evaluation
managed to price. `priced_elsewhere` is computed for every holding and read in
exactly one place — inside that branch.

A holding the router prices *wrongly but small* is classified `FORFEIT`, which
is swept **by default with no user action**, and the flag recording that the
evaluation values it at 245 ALGO is ignored. The protection is strictly weaker
in the case where the system is more confident and more wrong.

The naive fix is wrong and the finding says why: extending the same presence
test to `FORFEIT` would disable the feature, because genuine dust is normally
priced by both sources agreeing it is worthless. What is needed is a
disagreement test.

**Fixed** by `disputed_dust`, which refuses a forfeit when the evaluation
values the holding above the forfeit threshold — the threshold serving as its
own tolerance, so there is no new constant.

## 3. What was checked and found sound

Recording these matters as much as the findings — an audit that lists only what
it disliked gives no information about coverage.

- **`asnd` (clawback) beside a close.** The whitelist does not refuse `asnd`,
  and a positive-shape control permitting fields nobody thought of is the wrong
  default. But it is not exploitable: the chain refuses the combination
  outright — simulate returns `cannot close asset by clawback` — and the
  whitelist requires `aclose` on every transaction it passes. Worth adding for
  tidiness; not a finding.
- **The sender and receiver rules.** Anchored to the wallet's connected
  account, not to the response. They bind.
- **`pay` transactions in a close-out group.** Refused outright, which is the
  rule stopping the most damaging thing that could hide in a batch of sixteen.
- **Empty-holding close destinations.** Anchored to the wallet's address. They
  bind, and the test suite covers this thoroughly.
- **The base64/`Uint8Array` boundary.** Fixed the previous day; the browser
  test added with it is real coverage.
- **`opted_in` cannot promote anything but `UNPRICED`.** Structural, confirmed.
- **The dApp-position filter.** Any program other than `Balance` disqualifies
  the whole asset, and NFTs are excluded unconditionally.
- **The plan endpoint's gating.** `payload["address"] = self.address` overrides
  whatever the body claims, and `test_func` requires the address be linked to
  the requesting user. A sweep cannot be planned for somebody else's account.
- **`never_cache` on the plan endpoint.** Correct, and load-bearing: both
  halves of a stale plan would agree with each other, so the whitelist would
  not catch one.

## 4. A note on test coverage

`dustsweep.test.js` passed 121 tests at **100% line and branch coverage** of
`dustsweep.js`. The suites either side were healthy too — 123 in
`router/tests/test_sweep.py`, 62 in `engine/core/tests/test_sweep.py`. (After
the fixes: 137, 139 and 64, still at 100% line and branch.)

All three Medium findings survive that. Coverage records which lines ran, not
which claims were tested, and the test that appears to prove the close destination
binds sets `amount: "0"` — selecting the branch anchored to the wallet, the
one that was never in doubt. It is a correct test of the half that works.

This is the same shape as the `I2` → `S1` failure that prompted
[the methodology](methodology/README.md), and it is the second time in two days
it has been the thing that mattered. The general form is worth stating: **a
control's tests tend to exercise the cases its author had in mind, which are
the cases the author already handled.** Reading what the predicate is anchored
to is a different question from reading whether it is tested.

### Which applies to the fixes in this report

Every fix above was certified by example tests its own author wrote, in the
same commits — the exact pattern `S1` came from, repeated four times in good
faith. Passing tests are evidence the author believed the code was right, which
is the thing a review is supposed to check.

So the fixes were followed by **35 property tests** — 20 in
`router/tests/test_fuzz_sweep.py` under hypothesis, 15 in
`dustsweep.property.test.js` under fast-check. Every one is a *refusal*, so a
counterexample is always a holding that could be forfeited when it should not
be. They found [`S5`](findings/S5-malformed-evaluation-raises.md) on their
first run, in both languages at once.

The transactions the JS properties draw from are generated by
`make_corpus.py` with algosdk's encoder rather than by fast-check, for the
reason the example suite already gives: the decoder is being tested against
Algorand's canonical msgpack, and a generator emitting bytes would test it
against its own idea of that. What is fuzzed is the *group* and the
*description* — which is the right axis anyway, since `S2` was a relationship
between the two rather than a malformed transaction.

### And the properties were themselves mutation-tested

A property that catches nothing passes exactly like one that catches
everything, so each rule was disabled in turn:

| rule disabled in `closeOutProblems` | a property caught it |
|---|:---:|
| the fee cap | yes |
| the rekey refusal | yes |
| the amount refusal | yes |
| the group-size limit | yes |
| `S2`'s chain comparison | yes |
| `S2`'s fail-closed branch | yes |
| **`axfer`-only** | **no** |

The last is a finding rather than a gap. A payment carries `rcv`, not `arcv`,
so with the type check disabled a payment is *still* refused — by "pays
somebody else", verified rather than reasoned. The rule is defence in depth and
what it buys is the message. There is a test saying so now, so the next reader
does not have to rediscover it.

## 5. Out of scope

- **The wallet's own display.** Pera and Defly show a fee and a close-to
  address, so a sufficiently careful reader could in principle catch `S2` and
  `S3` at the prompt. That is not counted as a control here: the group carries
  up to sixteen transactions, and the reader has no reference value to compare
  against for either field.
- The AMM contracts, key management, deployment operations, formal
  verification, and economic modelling — as in [REPORT.md §5](REPORT.md).

This section used to carry a third entry: whether the two price sources
actually disagree on live data, which needs the full engine and was beyond what
the partial export here could produce. It has since been measured, and moves to
§6.

## 6. The divergence behind `S4`, measured

`S4` was argued structurally and from the documented xALGO/tALGO incident
rather than from a live measurement, because measuring one needs both halves at
once: an account evaluation, which only the full engine produces, and the
router's `al:*` map. With three real evaluations and a Redis read, from
[verification/measure-divergence.py](verification/measure-divergence.py):

```
accounts       : 3
holdings       : 104
priced by both : 90
router unpriced: 14

agreement (router value / evaluation value)
  min      0.753   (FAME on VW55K)
  median   1.001   (xALGO on 2EVGZ)
  max      3.503   (frUSDC on 2EVGZ)

in the router's forfeit band : 29
  disputed by the evaluation : 0
```

Three things follow, and the third is the one worth stating plainly.

**The guard is inert in normal operation.** A median ratio of 1.001 across 90
paired holdings is the two sources agreeing, and all 29 holdings in the forfeit
band are agreed by both. `disputed_dust` refuses nothing on this sample, so it
costs these users no dust holding they wanted swept. That is what a veto should
look like when nothing is wrong.

**The disagreement it exists for is real and large.** The tails are 0.753 and
3.503 — FAME priced 25% *below* the evaluation, frUSDC 250% above. The
dangerous direction is the low one, since that is what carries a holding down
into a 0.1 ALGO band it does not belong in. Nothing in this sample sits close
enough to the edge for a 25% error to move it across, but the width is not
hypothetical and the band is narrow.

**No live dispute was found today, and that is not evidence the finding was
wrong.** `S4` is about what happens when the router's price map is wrong, and
the xALGO/tALGO incident three weeks ago is the proof that it can be — an
entire asset class unpriced because one synthetic pool evicted every real one.
A sample taken while the cache is healthy shows the guard idle, which is the
expected reading, not a refutation. The measurement that would refute it is a
cache defect that produced no dispute, and this is not that.

Worth recording alongside: **14 of the 104 holdings are unpriced by the
router** and land in `UNPRICED`, where `S1`'s veto is what protects them. That
path is not an edge case.

## 7. Reproducing

```sh
ROUTER=/path/to/router WIDGETS=/path/to/widgets ENGINE=/path/to/engine \
ALGOD_URL=https://your-node SWEEP_ADDRESS=SOMEADDRESS… \
    ./verification/verify-sweep.sh

REDIS_AUTH=… ROUTER=/path/to/router \
    python verification/measure-divergence.py evaluation.json …
```

Reads only; submits nothing. The chain cases use `simulate` with
`allow-empty-signatures` and no key. Without `ALGOD_URL` and `SWEEP_ADDRESS`
those four checks report `SKIP` rather than passing silently.
