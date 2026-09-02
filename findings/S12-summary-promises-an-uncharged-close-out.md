# S12 — `summary` promises a close-out it never charges for

- **Severity:** Informational (1,000 microALGO per conversion)
- **Component:** off-chain — `router/sweep.py: summary`
- **Origin:** review of the sweep planner, 2026-09-02
- **Status:** **Fixed** — `2ae1c29` (router)

---

## 1. The defect

`S3` made `recoverable` net of fees, because a fee is as certain as the
minimum balance it is subtracted from. One term was missed:

```python
fees = closes * CLOSE_OUT_FEE + conversions * CONVERSION_FEE
recoverable = (closes + conversions) * HOLDING_MINIMUM_BALANCE - fees
```

Every conversion empties the holding it converts, and the next group closes
it — which is why its 0.1 ALGO is promised. That close-out's own 1,000
microALGO fee is not subtracted, while `prompt_count`, in the same returned
dict, counts the group that pays it.

## 2. Why it is Informational rather than Low

Three empty holdings and two conversions: `recoverable` says 471,000 where the
truth is 469,000. It over-promises by a thousandth of an ALGO per conversion,
in a figure the interface presents as approximate.

It is recorded because it is the same gross-against-net disagreement `S3`
found, in the same function, one term further along — and because a reporting
figure that drifts is how `S3` started.

## 3. The fix

`fees = (closes + conversions) * CLOSE_OUT_FEE + conversions * CONVERSION_FEE`.
