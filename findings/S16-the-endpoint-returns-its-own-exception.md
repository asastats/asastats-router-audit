# S16 — The sweep endpoint returns its own exception text

- **Severity:** Informational (hygiene; the endpoint is internal and
  scope-gated)
- **Component:** off-chain — `engine/core/views.py: InternalRouterSweepView`
- **Origin:** review of the engine's half of the sweep, 2026-09-02
- **Status:** **Fixed** — `44932aa` (engine)

---

## 1. The defect

```python
except Exception as exc:
    return Response({"detail": str(exc)}, status=400)
```

Any unexpected failure reaches the widget as its Python message. `S9` is how
this surfaces: a malformed cache entry arrived as

```
{"detail": "'str' object has no attribute 'get'"}
```

## 2. Why it matters at all

Two reasons, neither of them disclosure — this endpoint sits behind a
deployment token and a scope.

* A 400 whose `detail` is an `AttributeError` is indistinguishable, to the
  widget, from a real *"your request was wrong"*. The interface renders it to a
  reader as an explanation.
* It is the reason `S9`'s severity was first recorded as a 500 and had to be
  corrected: the failure is real, the status code was not.

## 3. The fix

A fixed message, with the detail logged through `logger.exception` where it is
useful to whoever operates the service rather than to whoever called it.
