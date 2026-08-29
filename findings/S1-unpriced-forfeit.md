# S1 — An unpriced holding could be forfeited with no value test

- **Severity:** Low (bounded by an explicit user action; unbounded in value)
- **Component:** off-chain — `router/sweep.py`, `engine/core/sweep.py`
- **Not a contract defect.** The router application is not involved.
- **Origin:** this audit
- **Status:** **Fixed** — `1c128f2` (router), `e13841f` (engine)

---

## 1. What the dust sweep does

It closes out ASA holdings a user no longer wants. An ASA holding locks 0.1
ALGO of minimum balance, so closing an empty one is free money; closing one
that still has a balance requires somewhere to send it, and the only target
that always works is the asset's **creator** — closing to self is refused
while the holding is non-empty, and closing to a stranger is refused unless
they have opted in.

So a "forfeit" gives the entire remaining balance to the asset's creator. It
is the only part of the sweep that can take something from a user, and the
design accounts for that: a holding nothing could value is classified
`UNPRICED` and is never swept by default. The user must tick it.

## 2. The defect

`closeable` decided what a close-out group may carry:

```python
forfeits = [
    one
    for one in holdings
    if one.asset not in excluded
    and (
        one.disposition == FORFEIT
        or (one.disposition == UNPRICED and one.asset in opted_in and one.creator)
    )
]
```

The `UNPRICED` branch tests three things: that the user opted in, that the
asset has a creator, and nothing else. **There is no bound on what is being
given away.** The entire safety of the operation rests on the user's judgement
about an asset the system has just told them it cannot value.

## 3. Why that is worse than it sounds

**"Unpriced" is a statement about the router's price cache, not about the
asset.** The sweep values a holding from the router's `al:*` map. The account
evaluation that renders the user's own portfolio page prices assets by an
entirely different route. Either can have a gap the other does not.

On the audited revision that gap was live. The liquidity cache writes one
synthetic "pool" per liquid staking asset to carry the protocol's redemption
rate, with a `balance1` of 10\*\*18. The cache's top-pool filter keeps only
pools holding more than one percent of an asset's total — and one percent of
10\*\*18 is ten billion ALGO, against eighteen million for the deepest asset on
the network. Every real xALGO and tALGO pool was therefore evicted, both
assets were unpriced, and both carry a creator.

Measured on a real account the same day, with the evaluation warm:

```
LFTY0046   router price: none    evaluation price: 245.878745 ALGO
Snorkz     router price: none    evaluation price:   0.000013 ALGO
WALGO      router price: none    evaluation: could not value it either
```

The first line is the finding. An asset worth about 246 ALGO, displayed with
that value on the user's own portfolio page, classified `unpriced` by the
sweep and one checkbox away from being sent to its creator.

## 4. Why the previous audit missed it

v5 examined this subsystem and marked it **VERIFIED SAFE**, citing "982 test
cases" — the file collects 111 — and concluding that "user approvals are
required before submission". Two problems. The approval claim is true of one
disposition out of four (`forfeit` is `included: true` by default in the
widget). And the predicate above was never read.

The general lesson is in [DISCLAIMER.md](../DISCLAIMER.md): a test asserting
that something is safe is not evidence that it is, particularly when the test
was written in the same commit as the code.

## 5. The fix

A veto, sourced from the payload the sweep already loads:

```python
or (
    one.disposition == UNPRICED
    and one.asset in opted_in
    and one.creator
    and not one.priced_elsewhere
)
```

`priced_by_evaluation` reads the account evaluation for assets it managed to
price, and those cannot be forfeited whatever the caller opts in to.

Three properties, each chosen deliberately:

- **It is a veto, not a valuation.** It removes candidates and never adds one,
  so a false positive costs the user a dust holding they keep, while a false
  negative costs them only what the unguarded code already cost them.
- **`notevals` is not read.** That list is by definition what the evaluation
  *could not* value, so an entry there is agreement rather than a second
  opinion.
- **The opt-in still works.** An asset neither side could price stays
  forfeitable, or the control it guards would be dead.

## 6. Verified on live data

Same account, three unpriced holdings, sweeping with the evaluation warm:

| opted in | recoverable |
|---|---|
| nothing | 5,300,000 |
| LFTY0046 + Snorkz — *both priced by the evaluation* | **5,300,000 — refused** |
| WALGO — *nothing priced it* | **5,400,000 — allowed** |

The delta is exactly 100,000 microALGO: one holding's minimum balance. The
veto refuses the two it should and leaves the third reachable.
