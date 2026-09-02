# S14 — The fee waiver's boundary cannot refuse anything its caller can present

- **Severity:** Informational (the properties it checks are true today; the
  boundary is not independent, and its test coverage only looks like coverage)
- **Component:** off-chain — `engine/core/sweep.py: sweep_discount`
- **Origin:** review of the engine's half of the sweep, 2026-09-02
- **Status:** **Fixed** — `44932aa` (engine)

---

## 1. What it claims to be

`sweep_discount` is introduced as *"the security boundary of the whole
feature"*, and its four unit tests are written as attacks, each naming the one
it stops. `DUST_SWEEP_DISCOUNT` is a hundred percent, minted into a
backend-signed voucher and enforced on chain — so this is the gate that
matters.

## 2. The defect

Its only caller is `_conversion`:

```python
discount = sweep_discount(ASASTATS_ASSET_ID, chosen.value, ceiling)
```

and every condition is already guaranteed before it runs:

| the guard | why it cannot fire | the test that "covers" it |
|---|---|---|
| `asset_out != ASASTATS` | the caller passes the **literal** | `…refuses_a_route_to_anything_else` |
| `value is None` | `CONVERT` requires a value | `…refuses_an_unvalued_input` |
| `value <= 0` | `CONVERT` requires `value > 100_000` | `…refuses_a_worthless_input` |
| `value > ceiling` | `CONVERT` requires `value <= ceiling`, and `_conversion` is passed the **same** ceiling | `…refuses_a_holding_above_the_ceiling` |

Demonstrated across holdings spanning `None`, `0`, `-1`, the forfeit band, the
ceiling and ten times over it: every candidate `convertible` yields earns the
full waiver, and none of the four values the refusal tests use can reach the
function at all.

## 3. Why this is Informational

Nothing is exploitable. The gate is held closed by `router.sweep.classify`, in
the other repository, rather than by itself — so the finding is that the
boundary is not independent and its tests prove less than they appear to.

## 4. The fix

Two things the function was not asking:

* `MAX_THRESHOLD_ALGO`, which is neither the caller's number nor `classify`'s,
  so it still bites if either changes.
* the **route that came back**. `group` builds against `quoted["asset_out"]`
  and the quote carries that field; checking the argument instead of the answer
  meant a quote for another asset would still have earned the waiver.
