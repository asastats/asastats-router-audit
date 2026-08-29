# Finding I1: Liquid Staking Asset Pricing Rate Oracle Boundary

- **Severity:** Informational
- **Category:** Quoter Architecture / Price Discovery
- **Location:** `router/selection.py`, `utils/liquidities.py`, `utils/pool_filters.py`
- **Origin:** v5 Audit (Commit `75087b8`)
- **Status (v5):** **VERIFIED SAFE — off-chain only, and not load-bearing on chain**

> **This finding was rewritten on 2026-08-29.** As first issued it cited, as its
> sole evidence, a test class written in the very commit under audit. See
> [../CORRECTIONS.md](../CORRECTIONS.md).

---

## 1. Description

The engine writes one synthetic "pool" per liquid staking asset whose balances
state the protocol's redemption rate rather than reserves: `balance1` is a flat
10\*\*18 and `balance2` is derived from it. The ratio is a price; neither number
is liquidity anyone can trade against.

The boundary worth auditing is therefore **which of the two the quoter treats
it as**, in three separate consumers: the price map, the depth signal, and the
per-counterpart leg signal.

---

## 2. What was actually verified

Read against the code rather than inferred from test names:

- **Price:** `asset_prices` uses a rate pool only when the asset has no usable
  reserve pool. Real pools answer first and take over on their own. The
  original text of `IS-IT-SAFE.md` had this inverted, and has been corrected.
- **Depth:** `pooled_depth` and `leg_depths` exclude rate pools via
  `_is_placeholder`, matched on a **code suffix** (`fl`, `tl`, `ml`, `cl`), so
  a provider that starts returning a pool again cannot inject 10\*\*18 of
  "depth". A list of two codes would not have covered that.
- **Cache construction:** `utils/liquidities._top_liquidity_pools` sets rate
  pools aside before the one-percent top-pool threshold, and
  `utils/pool_filters._non_deviating_pools` lets them neither vote in nor be
  judged by the price-deviation filter — the vote is weighted by `balance1`, so
  a rate pool left in would outvote every real pool of the asset by roughly a
  trillion to one.

**Corroborated against live reserves on 2026-08-29:** xALGO's pools price at
1.221486 against a protocol rate of 1.221808 (−0.021%), tALGO's at 1.096195
against 1.090549 (+0.518%), over 518,202 and 566,465 pooled ALGO respectively.
The two sources agree, which is what makes the fallback safe to have.

## 3. Why the on-chain exposure is nil

This is quoter-side only. The contract never reads a price: the floor it
enforces arrives co-signed by `quote_signer` in a transaction note, and the
realised output is measured by holding delta. A wrong price produces a *worse
quote*, not a bypassed floor.

The residual it does carry is the same one every asset carries — a floor is
only as good as the price the signer derived it from — and it is not specific
to liquid staking. It is bounded off-chain by the retention guard
(`DEFAULT_RETENTION`, 90%) and the disagreement guard
(`PRICE_DISAGREEMENT`, 110%).

## 4. The failure this had already caused, which the first draft did not mention

Before `75087b8` the rate placeholder was **evicting** the assets' real pools
from the cache: its synthetic `balance1` made the one-percent top-pool
threshold ten billion ALGO, against eighteen million for the deepest asset on
the network. Both assets therefore had no price and no depth at all, which

- made the dust sweep call them `UNPRICED` and offer them for forfeit — see
  finding `I2`, where that combination was a live hazard; and
- silently disarmed `router.quote._implied_rate`, and with it the stale-pool
  corroboration check in `_direct_reference`, on every pair ending in either
  asset.

Both are fixed. The point for a future reviewer is that the dangerous direction
here was never "a rate mistaken for liquidity" — it was **a rate suppressing
the liquidity that was really there**.
