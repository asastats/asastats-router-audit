# S15 — "It did not raise" is not the same as "there is an answer"

- **Severity:** Informational (the holding is refused either way; the cost is a
  wrong sentence)
- **Component:** off-chain — `engine/core/sweep.py: evaluation_for`
- **Origin:** review of the engine's half of the sweep, 2026-09-02
- **Status:** **Fixed** — `44932aa` (engine)

---

## 1. The distinction the code documents

`holdings_for` takes `evaluated` to mean *"whether `evaluation` is an answer at
all"*, and says of the two cases:

> False means the evaluation could not be read, which is **not** the same as an
> account with nothing in it, and the two must not collapse into one empty dict

## 2. The defect

They collapse. `evaluation_for` returned `(evaluation, None)` on every path
that did not raise, so a rebuild returning `{}` was reported as a successful
read. `holdings_for` was then told `evaluated=True` with nothing to read.

Every holding with a balance is refused as `COMMITTED_DAPP` — *"belongs to a
position in some dApp"* — where the truth is `COMMITTED_UNKNOWN`, *"the sweep
could not read which of this address's holdings are free"*. And
`evaluation_unavailable` reports `None`, so nothing downstream can tell either.

## 3. Why it is Informational

Both readings refuse the holding, so nothing is given away. What is lost is
that a reader is told their token is part of a dApp position when the truth is
that we could not read the evaluation — and that the field designed to say so
says nothing.

## 4. The fix

`evaluated` is derived from whether there is an answer, not from the absence of
an exception.
