# S13 — Only the quote call is contained, so a conversion failure takes the close-outs with it

- **Severity:** Medium (it loses the half of a sweep that carries most of the
  value, and needs no router at all)
- **Component:** off-chain — `engine/core/sweep.py: _conversion`, `plan`
- **Origin:** review of the engine's half of the sweep, 2026-09-02
- **Status:** **Fixed** — `44932aa` (engine)

---

## 1. The promise

`plan` states it twice in prose:

> A router that cannot build does not stop a sweep. Conversions need the router
> application; close-outs do not, and carry most of the value.

and implements it for exactly one exception class:

```python
except RouterUnavailable as error:
```

## 2. The defect

`QuoteExpired` is a **sibling** of `RouterUnavailable`, not a subclass, and
`group()` raises it on both of its re-quote checks. In `_conversion` the `try`
covered only the `quote()` call; `_topology()`, the retention arithmetic,
`sweep_discount` and the whole of `group()` sat outside it.

So the same exception was a per-candidate refusal or fatal depending on which
of two adjacent lines raised it:

| what fails | where | result |
|---|---|---|
| `RouterUnavailable` | `group()` | close-out group offered ✓ |
| `QuoteExpired` | `group()` | **`plan` raises; nothing offered** |
| `QuoteExpired` | `quote()` | contained as a refusal ✓ |

## 3. It is not only `QuoteExpired`

The uncontained region holds a node round-trip for the voucher, the voucher
mint and the quote signing. Any of them failing cost the caller their
close-outs — and, by breaking the candidate loop, the second and third
candidates too.

## 4. Why the suite did not see it

The regression test for the original version of this bug patches
`core.sweep._conversion` **wholesale**, so the boundary *inside* `_conversion`
is never exercised. The promise was tested for one exception class and kept for
one exception class.

## 5. The fix

The whole candidate attempt is contained. Two regression tests: one for
`QuoteExpired` out of `group()`, one for a node failure mid-build.
