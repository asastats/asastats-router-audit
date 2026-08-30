# S4 — The evaluation veto guards the opt-in path but not the automatic one

- **Severity:** Medium (no user action required; needs only a wrong price, not
  an adversary)
- **Component:** off-chain — `router/sweep.py` `classify` / `closeable`
- **Origin:** this audit
- **Status:** **Fixed** — `2aad22b` (router), `9320ae2` (engine)
- **Relationship:** completes [`S1`](S1-unpriced-forfeit.md), which fixed the
  adjacent branch

---

## 1. What S1 fixed, and what it left

`S1` found that an `UNPRICED` holding the user ticked could be forfeited with
no value test, and the fix was a veto sourced from the account evaluation:

```python
forfeits = [
    one
    for one in holdings
    if one.asset not in excluded
    and (
        one.disposition == FORFEIT                     # <- no veto here
        or (
            one.disposition == UNPRICED
            and one.asset in opted_in
            and one.creator
            and not one.priced_elsewhere               # <- the S1 veto
        )
    )
]
```

`priced_elsewhere` is computed for **every** holding — `engine/core/sweep.py`
sets `priced_elsewhere=asset in priced` on each one — and read in exactly one
place. Grepping the two packages for it returns one consumer:

```
router/router/sweep.py:581:                and not one.priced_elsewhere
```

which is inside the `UNPRICED` branch. The `FORFEIT` branch never consults it.

## 2. Why that is the wrong branch to protect

The two branches differ in what the router's price map said, not in what the
holding is worth:

- a **gap** in the map (`None`) → `UNPRICED` → needs an explicit tick →
  vetoed by S1
- a **wrong small number** → `FORFEIT` → swept **with no user action at all**

The protection is strictly weaker in the case where the system is more
confident and more wrong. `forfeit` is `included: true` in the widget's
`DISPOSITIONS`; `unpriced` is the only disposition that starts off.

Run against the real `classify` and `closeable`
(`verification/verify-sweep.sh`, case 4) with an account evaluation pricing the
holding at 245.878745 ALGO in both:

```
--- router has no price at all ---
  disposition     : unpriced
  priced_elsewhere: True
  swept with NO user tick : False
  swept if user ticks it  : False

--- router has a wrong small price ---
  router value    : 50000
  disposition     : forfeit
  reason          : worth 0.0500 ALGO, less than the 0.1 ALGO its holding locks
  priced_elsewhere: True
  swept with NO user tick : True
  swept if user ticks it  : True
```

The second row is the finding. The evaluation says 245.88 ALGO, the flag
recording that is set, and the holding is swept by default — with the interface
telling the reader, confidently, "worth 0.0500 ALGO".

## 3. This needs no attacker

`S1`'s trigger was a cache defect, not an adversary: the liquid staking rate
placeholder's `balance1` of 10\*\*18 put the top-pool threshold at ten billion
ALGO and evicted every real xALGO and tALGO pool. That defect produced *no*
price, which is why it landed in the `UNPRICED` branch and why S1's veto
answers it.

A defect that leaves **one** thin pool standing instead of none produces a
small positive price instead of `None` — the same class of cache fault, one
pool either side of the same filter, landing in the branch with no veto and no
checkbox. `priced_by_evaluation`'s own docstring anticipates the general case:

> The cache defect is fixed; the shape that made it dangerous is not, and the
> next gap will be in some asset nobody has thought about.

That reasoning applies to `FORFEIT` at least as strongly as to `UNPRICED`.

## 4. Recommended fix, and the version to avoid

**Do not extend the existing veto as written.** Adding `and not
one.priced_elsewhere` to the `FORFEIT` branch would disable forfeits almost
entirely: the evaluation prices most assets, and genuine dust — the case the
feature exists for — is normally priced by both sources agreeing that it is
worth very little. The `UNPRICED` branch tolerates a presence test precisely
because reaching it already means the router had no opinion.

The forfeit branch needs a **disagreement** test rather than a presence test:
forfeit only when the evaluation either has no opinion, or agrees the holding
is at or below the forfeit threshold. Refuse when the two sources materially
disagree, and say so in the reason.

That needs a value, not a set. `priced_by_evaluation` returns the asset ids the
evaluation priced; this wants `asset -> value` from the same `asaitems` pass,
carried on `Holding` beside `priced_elsewhere`. It is the same payload, read
once more, so there is no extra fetch.

Three properties to preserve, following S1:

- **A veto, not a valuation.** It may only remove candidates. A holding the
  evaluation prices *lower* than the router must not become forfeitable
  because of this rule.
- **Silence is not disagreement.** An asset in `notevals` is the evaluation
  agreeing nothing priced it, so it must not block a forfeit.
- **A tolerance, not equality.** The two sources are different pricing routes
  and will differ slightly on everything. The threshold should be a
  disagreement large enough to matter against 0.1 ALGO, not any difference at
  all.

## 5. As delivered

`disputed_dust`, called from `classify` rather than `closeable`, so a refused
forfeit carries a reason the reader can see rather than vanishing from a list.

`values_by_evaluation` is a second reader of the same `asaitems` payload,
returning `asset -> microALGO`. It reads only `value`, never `price`: a price
is per base unit and turning one into a holding's worth needs decimals the
payload does not carry, so an entry with a price and no value contributes
nothing — leaving that holding exactly as it was rather than inventing a number
to compare against.

**The tolerance is the forfeit threshold itself**, which turned out to need no
new constant. Both sources calling a holding worth no more than the minimum
balance it locks is agreement; the evaluation calling it worth more than that
is a dispute, whatever the router said.

A vetoed holding becomes `KEEP`, not `UNPRICED`. `UNPRICED` would grow a
checkbox that `S1`'s veto then refuses — the asset *is* priced elsewhere — and
the widget's own `INERT` docstring already says a control that quietly does
nothing is worse than none.

## 6. Measured against live data

The divergence this finding rests on was argued from the xALGO/tALGO incident
rather than measured, because measuring it needs an account evaluation and the
router's `al:*` map at the same moment. Both, on three real accounts:

```
holdings       : 104        priced by both : 90
router unpriced: 14

router value / evaluation value
  min 0.753 (FAME)   median 1.001 (xALGO)   max 3.503 (frUSDC)

in the router's forfeit band : 29
  disputed by the evaluation : 0
```

**The guard is idle here, and that is the right result.** The two sources agree
to within a tenth of a percent at the median, and all 29 holdings the router
calls dust are agreed by the evaluation, so nothing this account wanted swept
is refused.

**The disagreement it guards against is real all the same.** FAME is priced 25%
below the evaluation and frUSDC 250% above. The low direction is the dangerous
one, because that is what carries a holding into a band 0.1 ALGO wide that it
does not belong in. Nothing here sits close enough to the edge for that to
happen today.

A healthy cache producing no dispute is the expected reading, not a refutation:
the fault this answers is a cache defect, and the xALGO one is three weeks old.

Reproduce with
[verification/measure-divergence.py](../verification/measure-divergence.py).
