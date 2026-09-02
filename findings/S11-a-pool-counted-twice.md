# S11 — A pool counted twice wherever the cache holds it under both keys

- **Severity:** Low (routing quality; it moves no value and refuses nothing)
- **Component:** off-chain — `router/selection.py: leg_depths`
- **Origin:** review of the sweep planner, 2026-09-02
- **Status:** **Fixed** — `7053a52` (router)

---

## 1. The premise, and where it fails

`leg_depths` scores an intermediate by its depth against a *named*
counterpart. The cache stores a pool under the asset it prices, so the function
writes both directions from each entry, on the stated premise that the cache is
one-directional:

> a HOG/USDC pool is in `al:HOG` with USDC as its counterpart and is simply
> absent from `al:USDC`

That is true for 2,018 pairs in a full dump and false for **95**, which are
stated under both keys. Each entry then writes both directions, so both
accumulate roughly twice the real depth — measured at 1.55× to 2.00×, median
**1.93×**. Not exactly double, because each side converts to ALGO through its
own price.

## 2. What it changes, in three populations

| population | pairs whose chosen intermediates change |
|---|---|
| 1,500 random pairs with cached depth | 0 |
| 3,540 pairs among the 520 assets over the depth floor | 2 |
| the benchmark's own six pairs | **2** |

Negligible network-wide — most pairs have no candidates to reorder — and it
lands on `usdc-hog` and `algo-hog`, both involving the asset the leg score was
built for.

## 3. The fix, and the fix that would have been wrong

Deduplicating on `(app, address)` is the obvious identity and it would have
**discarded real depth**: a STAMM pool is several sub-pools behind one
application and one address, and 10 such sibling groups are in the dump, one
with seven. So each *side* of a pair is totalled independently, siblings
included, and the pair takes the deeper of its two sides — which is also
independent of cache ordering, where taking whichever key came first would not
be.

## 4. What is not claimed

That quotes improve. A benchmark run against live reserves put the affected
pairs between the 36th and 81st percentile of 113 prior runs, median about 45%
— noise at that sample size. The case for the change is that a pool counted
twice is wrong, and that it holds across two cache vintages 19 days apart.
