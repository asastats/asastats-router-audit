# S10 — The forfeit guard reads a number without reading its currency

- **Severity:** Medium (it weakens the only automatic guard on the one
  disposition that gives a holding away unasked)
- **Component:** off-chain — `router/sweep.py: values_by_evaluation`
- **Origin:** review of the sweep planner, 2026-09-02
- **Status:** **Fixed** — `2ae1c29` (router)

---

## 1. The guard this is about

`S4` added `disputed_dust`: a holding the router prices as dust is not
forfeited if the *account evaluation* values it above the same threshold. It is
the only check standing between a wrong price and a holding being given away
without anyone ticking a box.

It compares `evaluated_value` against a microALGO threshold, and
`values_by_evaluation` produces that number:

```python
values[asset] = worth * MICRO_ALGO
```

## 2. The defect

**The payload states its own currency and this never read it.** Every
evaluation carries `account_info.values_in`; every one seen says `"ALGO"`. The
API also exposes a documented `usd` parameter, and the cache key is
`api:<address>` with **no currency component** — so whichever currency was
written first is what a later reader gets.

```
USD payload  -> {7: 90500.0}
ALGO payload -> {7: 90500.0}      # byte-identical
```

## 3. What a USD payload would do

Understate every holding by the ALGO price — about **elevenfold** at the
`pricealgo: 0.090472` stated in one of the captured payloads. A holding the
evaluation values at 1 ALGO reads as 90,500 microALGO, below the 100,000
threshold, and the dispute never fires. The guard is silently disarmed in
exactly the direction that lets a forfeit through.

## 4. What was not established

**Whether a USD payload can reach that cache key.** The serializer that sets
`values_in` and the view that writes the entry are both outside the reviewed
checkout. This is recorded as a latent defect rather than a live one; the fix
costs nothing either way.

## 5. The fix

The currency is honoured. `ALGO` or absent reads as before — absent matters,
because refusing older entries would switch the guard off for all of them.
Another currency is converted through `total.pricealgo`, checked against a real
payload: total 7,784.325949 × 0.090472 = 704.261906, which is the `totalusdc`
that payload also reports. A currency with no usable rate yields no values,
which is the position an unreadable evaluation is already in.
