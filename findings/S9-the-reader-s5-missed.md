# S9 — The evaluation reader `S5` missed, and it is the one that runs first

- **Severity:** Medium (availability — it takes the close-out half down with it)
- **Component:** off-chain — `router/sweep.py: sweep_filter`
- **Origin:** review of the sweep planner, 2026-09-02
- **Status:** **Fixed** — `2ae1c29` (router)

---

## 1. `S5` was fixed for four readers of five

`S5` found that several functions read the account evaluation and each assumed
its shape. The fix introduced `_evaluation_items`, a shape-tolerant reader, and
routed `priced_by_evaluation` and `values_by_evaluation` through it.

`sweep_filter` reads the same cache entry and was left reaching for it
directly:

```python
evaluation = evaluation or {}
for name in ("asaitems", "notevals"):
    for item in evaluation.get(name) or ():
```

That is correct for a dict and raises for everything else — which is exactly
what `S5` was about.

## 2. Why it matters more than the four that were fixed

**`holdings_for` calls it first**, at `core/sweep.py:287`, ahead of both
hardened readers. So the hardening never gets a chance to run: seven payload
shapes that `priced_by_evaluation` and `values_by_evaluation` tolerate never
reach them.

| payload | `sweep_filter` | the two hardened readers |
|---|---|---|
| a list instead of a dict | `AttributeError` | ok |
| a string | `AttributeError` | ok |
| `asaitems` is a dict | `AttributeError` | ok |
| an item that is not a dict | `AttributeError` | ok |
| `asset` that is not a dict | `AttributeError` | ok |
| a non-numeric asset id | `ValueError` | ok |
| `programs` is not a list | `TypeError` | ok |

## 3. Reachability is documented in the cache layer

`cached_api_bundle` → `mcached_data` returns `msgpack.unpackb(value)` with no
shape validation, and its own docstring declares `:return: dict or str`. A
`str` is truthy, so `evaluation_for` returns it as a successful read,
`holdings_for` is called with `evaluated=True`, and `sweep_filter` raises.

Nothing in `plan` catches it — only `_convert_payload` is wrapped — so it
reaches the view, which answers 400 with the raw exception text (`S16`).

## 4. What is lost

The whole sweep, **including the close-out half**, which needs no evaluation at
all and is where most of a sweep's value is. That is precisely the failure
`plan`'s two documented degradation paths exist to prevent.

## 5. The fix

`_evaluation_items` takes a list name, and `sweep_filter` uses it. All three
readers now share one shape-tolerant reader — which `verify-sweep.sh` asserts,
having previously required exactly two.
