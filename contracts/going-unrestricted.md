# `RESTRICT_TO_ADMIN`, before and after it came off

Not a finding. A note on the one decision this series keeps circling, written
down because it had been asked three times and answered wrongly twice.

**It came off on 2026-08-30.** Mainnet `3692588382` serves the public. This
document was written the day before, as an argument about what would have to
exist first; it is kept in that order because the answer is only worth anything
if you can see what was asked. §"What actually happened" is at the foot.

## What the control is

```python
if TemplateVar[UInt64]("RESTRICT_TO_ADMIN"):
    assert Txn.sender == self.admin, "restricted while under test"
```

It gates `route`, `route3` and `close_holding`. It is a **template variable**,
so it is fixed at compile time and removing it is a redeploy rather than a
setting. The assertion message is the contract's own framing: *while under
test*. This was always meant to come off.

At the time of writing, mainnet `3688554446` had it set and testnet
`770123816` did not. Both are now retired; neither survivor sets it.

## What happened the last two times

| | |
|---|---|
| **v4** | Recommended removing it, on the grounds that "mainnet has been running unrestricted for months". Mainnet was the restricted one. The application id cited as evidence, `769636397`, was the **testnet** deployment. |
| **v5** | Recorded the removal from mainnet `3688554446` as **already delivered**. It had not happened. On that basis its summary opened "secure for unrestricted mainnet production deployment". |

Both arguments were fluent, both were confident, and both rested on a statement
of fact that one command would have refuted. The direction is not random: an
audit that concludes "this is fine" reads as a successful audit, and the
control standing between an unaudited contract and the public is the thing that
"fine" most wants to remove.

**A third AI opinion on this question is worth very little**, including this
one. What follows is therefore not an argument that the contract is ready. It
is a description of one mechanism that holds whether or not it is, and of a
second that was built for the same purpose and removed because it could not.

## The gap nobody had named

While the restriction is compiled in, the admin is the only caller, so **the
restriction is also the stop button**. Take it off and there is no stop button,
because the contract had none: `set_admin`, `set_escrow`, `set_fee`,
`set_voucher_signer`, `set_quote_signer`, `set_conversion_pool` and
`delete_application` were the entire administrative surface, and
`delete_application` refuses while anything is accrued or held.

Going from *one caller* to *everybody*, and from *a stop button* to *none*, in
a single redeploy is the part that was hard to justify — and it was invisible,
because while the restriction is on you never notice it is doing two jobs.

## The mechanism

In the contract now, and it does not depend on any audit being correct — which
is the entire reason to prefer it to more analysis.

### `set_paused`

Stops routing in one transaction. Asserted in `route` and `route3`, directly
below the restriction so the two read together.

**Routing only, deliberately.** `close_holding`, the setters and
`delete_application` keep working while paused, because they are how an
administrator recovers from whatever caused the pause. A pause that froze the
recovery path would be a worse position than not pausing at all — and
`verify-sweep.sh` checks that `close_holding` does *not* consult it.

Nothing is custodied across the boundary: a route is atomic, the contract holds
a caller's input only within the group, and `_pay_out` pays `Txn.sender` before
it ends. Pausing stops the next route and cannot strand one in flight.

### There is no input cap, and that is a decision

One was built and then removed, which is worth recording because the reasoning
generalises.

The intent was a rollout limiter: bound what a single route could lose, so the
first weeks of unrestricted traffic could not cost more than a number, whatever
turned out to be wrong. That is a good idea. The implementation bounded
`_input_amount`, which is denominated in **the input asset's base units** — so
`50_000_000_000` was 50,000 ALGO and equally 50,000 USDC, an order of magnitude
apart in worth, and something else again for every other decimals value.

**A limit that cannot state the quantity it is limiting is not a limit.** It is
a number that happens to refuse some trades and not others, on a basis nobody
reading it would predict. Expressing it in value terms is the only way it means
what it was meant to mean, and that requires a price oracle inside the
contract — a larger and worse thing than the bound it would calibrate.

So it went, rather than staying as a feature that needed a warning attached.
`verify-sweep.sh` asserts its absence, so it cannot come back quietly.

What survives is the half that never depended on pricing anything.
`set_paused` bounds *duration* rather than size: it needs no notion of value,
and it is the mechanism that actually replaces what `RESTRICT_TO_ADMIN` was
silently doing.

## A suggested sequence

The redeploy that lifts the restriction has two things to carry: the group fee
bound from [`S3`](../findings/S3-unbounded-fee.md), and the pause.

Deploying **with the restriction still on** first, and exercising the pause
against your own account on mainnet, costs one extra deployment and converts "we believe the lever works" into "we have pulled it". A stop
button nobody has pressed is a claim, not a control — which is the whole
argument of this repository, applied to its own recommendation.

---

## What actually happened

`3689591968`, 2026-08-30. Both mechanisms carried, and the pause was exercised
rather than assumed — on testnet first, in both directions, then on mainnet
within minutes of the create:

```
round 64574891   paused, immediately after create
round 64574900   fee 0 -> 5
round 64574945   resumed
round 64574958   predecessor 3688554446 retired, 4.998001 ALGO recovered
```

Not the extra deployment this document suggested, but the same property by a
cheaper route: the contract was inert while it was configured, and the lever
was pulled before any stranger could reach it. What it did **not** do is
exercise the pause against live third-party traffic, which is a different and
untested thing.

Two facts about that deployment worth having in one place, because they are
what a reader will want to check:

- **`RESTRICT_TO_ADMIN: 0`** in the manifest, and — the half that cannot be
  edited — four groups in [evidence/](../evidence/) that routed from an account
  which is not the admin.
- **`fee_bps` moved 0 → 5**, the first time the rate has ever been charged to
  a stranger. Every fee taken in the live evidence is exactly
  `floor(ALGO leg × 5 / 10000)`; the ceiling `set_fee` enforces is 100.

`verify.sh` reads the manifest rather than describing it, and
`verify-groups.py` reads the groups. Neither reads this paragraph.

## What none of this substitutes for

A human with Algorand experience reading the contract.
[DISCLAIMER.md](../DISCLAIMER.md) records that none ever has. That gap was
tolerable while the admin was the only caller. **They are not any more, so it
is now the whole question**, and the pause is the only thing bounding it — it
bounds how long being wrong lasts, and does nothing at all to make being wrong
less likely.
