# Finding I2: Dust Sweep Portfolio Classification Policy

- **Severity:** Informational (the gap below was Low, and is fixed)
- **Category:** Portfolio Management / Asset Classification
- **Location:** `router/sweep.py`, `tests/test_sweep.py`
- **Origin:** v5 Audit
- **Status (v5):** ~~VERIFIED SAFE~~ → **GAP FOUND AND REMEDIATED 2026-08-29** (`1c128f2`)

> **This finding was rewritten on 2026-08-29.** As first issued it read
> "VERIFIED SAFE", cited a test count wrong by a factor of nine, and did not
> examine the predicate that decides the question. See
> [../CORRECTIONS.md](../CORRECTIONS.md).

---

## 1. Description

The dust sweep classifies each holding as Empty (close to self), Forfeit (close
to the asset's creator), Convertible (swap to ASASTATS), Keep, Unpriced, or
Committed (staked/locked/NFT). A **forfeit sends the entire remaining balance
to the asset's creator**, so classification is the only part of the sweep that
can take something from a user.

---

## 2. What was actually verified

Checked against `router/sweep.py` at revision `ca58dd6`:

| Claim | Verdict |
|-------|---------|
| NFTs excluded unconditionally | **True** — `committed_reason` refuses them before any valuation |
| dApp positions excluded, including at zero balance | **True** — the opt-in is the slot the protocol repays into |
| A holding with no creator is never forfeited | **True** — `closeable` requires `one.creator`; there is no valid close target otherwise |
| A missing price never reads as zero | **True** — `classify` tests `value is None` *before* any threshold |
| "user approvals are required before submission" | **False as written** — see below |

## 3. The gap

**Forfeit is included by default, not approved.** In `dustsweep.js`,
`DISPOSITIONS.forfeit` is `included: true`. A holding the router priced below
the 0.1 ALGO forfeit threshold is in the group unless the reader *deselects*
it. Only `unpriced` is `included: false`. The original wording implied a
per-line opt-in that exists for one disposition out of four.

**And the unpriced branch had no value test at all.** `closeable` read:

```python
or (one.disposition == UNPRICED and one.asset in opted_in and one.creator)
```

Any asset the router failed to price, that has a creator, was given away in
full when the reader ticked its line. Nothing bounded what was being given.

This was not theoretical on the audited revision. Until the same day, a liquid
staking rate placeholder had evicted every real xALGO and tALGO pool from the
engine's `al:*` cache — a synthetic `balance1` of 10\*\*18 against a top-pool
threshold of one percent. The router therefore priced neither asset, both
classified `UNPRICED`, and both carry a creator. A reader who ticked their
unpriced lines would have handed the Folks and Tinyman staking contracts an
asset the address page was, on the same screen, valuing at over an ALGO a unit.

**"Unpriced" is a statement about the router's cache, not about the asset.**

## 4. Remediation

`1c128f2` adds `router.sweep.priced_by_evaluation`, which reads the account
evaluation — the payload `sweep_filter` already consumes — for the assets it
managed to price, and `closeable` now refuses to forfeit those whatever the
caller opted in to:

```python
or (
    one.disposition == UNPRICED
    and one.asset in opted_in
    and one.creator
    and not one.priced_elsewhere
)
```

It is a veto rather than a valuation: it removes candidates and never adds one,
so a false positive costs a reader a dust holding they keep. `notevals` is
deliberately not read — it is by definition what the evaluation *could not*
value, so an entry there is agreement rather than a second opinion. The engine
half is `e13841f`.

## 5. Test evidence

The original text claimed "982 test cases" for `tests/test_sweep.py`. The file
collected **111** at the audited revision and **123** after the fix. Across all
four suites the sweep subsystem has router 111, engine 61, widget jest 121,
browser 30 — **323** at the audited revision.
