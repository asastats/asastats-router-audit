# Before `RESTRICT_TO_ADMIN` comes off

Not a finding. A note on the one decision this series keeps circling, written
down because it has now been asked three times and answered wrongly twice.

## What the control is

```python
if TemplateVar[UInt64]("RESTRICT_TO_ADMIN"):
    assert Txn.sender == self.admin, "restricted while under test"
```

It gates `route`, `route3` and `close_holding`. It is a **template variable**,
so it is fixed at compile time and removing it is a redeploy rather than a
setting. The assertion message is the contract's own framing: *while under
test*. This was always meant to come off.

Mainnet `3688554446` has it set. Testnet `770123816` does not.

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
is a description of two mechanisms that hold whether or not it is.

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

## The two mechanisms

Both are in the contract now. Neither depends on any audit being correct, which
is the entire reason to prefer them to more analysis.

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

### `set_max_input`

Bounds what one route may take in. Asserted in `_input_amount`, which is where
both entry points already learn what the caller paid, and on both its branches
— the ALGO one and the ASA one.

Starts at **50,000 ALGO**, about US$4,000 when it was chosen. Raising it is an
administrative act with a transaction behind it; zero is refused rather than
meaning "unlimited", because a sentinel that opens the contract wide is the
wrong thing to reach by accident.

**It is a rollout limiter, not a security boundary**, and the distinction
matters. Nothing here is safer at 50,000 ALGO than at 500,000. What the cap
buys is that the first weeks of unrestricted traffic cannot lose more than it,
whatever turns out to be wrong — which is worth having precisely because the
evidence that nothing is wrong is six AI audits, two of which were confidently
mistaken about this very question.

**One honest limitation.** The cap counts base units, so `50_000_000_000` is
50,000 ALGO and also 50,000 USDC, an order of magnitude apart in worth. A
stablecoin route is therefore capped looser in dollars than an ALGO one.
Pricing per asset would put an oracle inside the contract, which is a larger
and worse thing than the limit it would calibrate; it is set against ALGO
deliberately, on the understanding that the number is reviewed while it is low.

## A suggested sequence

The redeploy that lifts the restriction has three things to carry: the group
fee bound from [`S3`](../findings/S3-unbounded-fee.md), the pause, and the cap.

Deploying **with the restriction still on** first, and exercising the two new
admin methods against your own account on mainnet, costs one extra deployment
and converts "we believe the lever works" into "we have pulled it". A stop
button nobody has pressed is a claim, not a control — which is the whole
argument of this repository, applied to its own recommendation.

## What none of this substitutes for

A human with Algorand experience reading the contract.
[DISCLAIMER.md](../DISCLAIMER.md) records that none ever has. That gap is
tolerable while the admin is the only caller and becomes the whole question the
moment they are not. The pause and the cap bound what being wrong costs; they
do not make being wrong less likely.
