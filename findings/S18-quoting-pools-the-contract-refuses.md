# S18 — The router quotes 447 AlgoFi pools its own contract will not trade

- **Severity:** Low (no funds are at risk; the caller's swap fails, and how
  late it fails depends on where the pool lands — for a routed leg it fails on
  chain, after they have signed)
- **Component:** off-chain — `router/venues.py` `algofi_venues`, against the
  `ALGOFI_POOLS` list compiled into `contracts/router_app.py`
- **Origin:** asking what happens to the pools the `S8` fix does *not* accept,
  2026-09-03
- **Status:** **Fixed** — `f6253ac` (router)

---

## 1. The mismatch

The contract will execute an AlgoFi leg only through an application on a list
compiled into it:

```python
self._assert_listed(leg.app.as_uint64(), TemplateVar[Bytes]("ALGOFI_POOLS"))
```

The list has **23 entries**, and it is a list rather than a creator pin for a
good reason, recorded where it is defined: AlgoFi's pools were deployed
permissionlessly, a sample of sixteen had twelve distinct creators, and there
is nothing to authenticate them by.

The quoting layer knew nothing about it. `ALGOFI_MAINNET_POOLS` lived in
`scripts/deploy.py`, which `router/` cannot import, so `algofi_venues` offered
every AlgoFi pool the graph could read. Measured on the graph the checkout
ships:

| | |
|---|---|
| AlgoFi pools the graph offers | **470** |
| ...on the contract's list | 23 |
| ...**not** on it | **447** |
| pairs with any AlgoFi pool | 423 |
| ...offering at least one unlisted | **412** |

For ALGO/USDC the graph offers three AlgoFi pools — `605929989`, `613193782`
and `919950071` — and only the first is listed.

## 2. What happens when one is chosen

It depends where the pool lands, and the worst case is the one the caller sees
last:

| where | what happens | since |
|---|---|---|
| inner leg of a route | the group **reverts on chain** at `_assert_listed` — after the caller has signed it in their wallet | as long as the contract has had the list |
| direct leg beside a route | the **quote signer refuses** it, because `S8`'s destination rule applies the same list to where a group may pay | 2026-09-03 |
| a direct-only group | nothing; it works. There is no route call, so no note, and the signer never sees it | — |

**The refusal cannot be recovered from.** `core/router.py` calls
`sign_quote_authorization` once. There is no `try`, no retry, and no path that
drops the offending venue and re-quotes — by then the group is built, its ids
are assigned and the note is written, so one leg cannot be removed without
rebuilding everything. The caller gets `RouterUnavailable`, not a swap.

## 3. Reachability

**Reachable by construction, not observed in practice.** Route hops must clear
`MINIMUM_POOL_MICROALGO`, 50 ALGO, and the 23 listed pools are every AlgoFi
pool holding at least 100 ALGO as measured on 2026-08-12 — so an unlisted pool
holding between 50 and 100 ALGO can pass the floor and be allocated.

Against that: across **224 live quotes** built through `group_for_quote` on
2026-09-03, AlgoFi was allocated in 7 and the pool was the listed one every
time. That matches the deployment note that across the four sweeps to
2026-08-11 the allocator chose an AlgoFi pool twelve times and it was
`605929989` on all twelve.

So this is a trap that had not yet sprung, and it is recorded because "has not
happened yet" is not a control.

## 4. The fix

`algofi_venues` drops a pool that is not on the list, before reading it:

```python
if int(edge.manager) not in ALGOFI_MAINNET_POOLS:
    return []
```

The failure becomes *not chosen* rather than *reverted* or *refused*, which is
the only one of the three the caller never has to see. It is also cheaper: a
pool that cannot be traded is not worth a round trip to price.

What it costs is liquidity that could not be traded anyway — everything dropped
held under 110 ALGO between them, and AlgoFi is shut down, so no new pool is
coming.

## 5. Why it was found now, and what that says

It came out of a question about the `S8` fix rather than from anything failing:
that fix pins the destinations a group may pay to the same provider rules the
contract uses, which meant moving the whitelists out of `scripts/deploy.py` and
into `router/providers.py`. Once quoting *could* see the list, the fact that it
never had became visible.

That is the same shape as `S9` and `S12` — a defect exposed by reviewing a fix
rather than by reviewing the code the fix touched. It is also the fifth time in
this series that **one copy of a rule in two places** turned out to be one copy
too few, which is why the fix moved the constants rather than duplicating them.
