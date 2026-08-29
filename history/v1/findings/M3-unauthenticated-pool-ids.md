# M3 — Pact / STAMM / AlgoFi pool application IDs are not authenticated

**Severity:** Medium
**Location:** `router/contracts/router_app.py`, `_swap_leg` dispatch
**Status:** **Patched**

## Description

Every non-Tinyman leg carried an application identifier in `leg.app` that the
contract then called. Nothing checked it. The router would send an inner
application call, from its own address, to whatever a caller nominated —
together with a deposit of the caller's funds.

Tinyman was never exposed: its pools are logic signature accounts, the
validator is a compile-time template variable, and `_tinyman_v2_pool` derives
the address from the pair being traded. That was the T5 fix. The other three
providers never got the equivalent.

## Impact

Atomicity and the authorised floor (H1) mean a hostile pool cannot take a
caller's trade: one that keeps the input and pays nothing leaves `received` at
zero, which fails a floor the caller can no longer choose. That is why this was
a medium and not a high.

What remained was an unbounded call surface — a confused deputy that would call
anything, from the router's own address — plus griefing, and the fact that all
of it becomes every caller's to aim the moment `RESTRICT_TO_ADMIN` comes off.

## Fix as implemented

Two mechanisms, because the providers differ in a way that matters. Both are
compile-time template variables, so no caller can widen either, and both are
checked in `_swap_leg` before dispatch — one place, where the provider with
nothing to check is visible beside the three that have.

### Pact and STAMM — pinned by pool creator

`AppParamsGet.app_creator`, compared against a concatenation of allowed
32-byte addresses. Roughly five opcodes, no state, no boxes, and **no extra
resource reference** — the pool application is already available because the
contract is about to call it.

Chosen on a full mainnet scan, 2026-08-12:

| Provider | Pools scanned | Creators |
|---|---|---|
| Pact | 3,218 | 3,189 `E5QGPA7LW…`, 21 `PACTFIIF…`, 8 `H2XDAF…` |
| STAMM | 311 | **311 — one address** |

One value covers every pool a provider will ever deploy, which a list of pool
identifiers cannot: both add pairs constantly, and a list would be wrong the
day they did.

**Not the program hash**, which would authenticate the code rather than the
deployer: Pact's current deployer ships at least three distinct approval
programs (2,208, 2,080 and 2,147 bytes), so it would take a set of hashes that
breaks on every upgrade — and hashing a two-kilobyte program costs more opcodes
than a route has to spend.

**The third Pact creator is deliberately excluded.** `H2XDAF…` is the address
of Pact's new pool factory (application 3656084442, itself created by
`PACTFIST…`), and its eight pools carry a different contract entirely:
lowercase `asset_a` / `reserve_a` / `weight_a` state where every earlier
generation has `A`, `B` and `CONFIG`. `pactsdk` cannot read them —
`fetch_pool_by_id` raises `KeyError: 'CONFIG'` — and `_pact_leg` sends a `SWAP`
call they do not implement. They are omitted because **this router cannot trade
through them**, not because they are untrusted, and refusing at our own
boundary beats failing inside someone else's contract.

### AlgoFi — a list, and a curated one

AlgoFi's pools were deployed permissionlessly: a sample of sixteen had **twelve
distinct creators**. There is nothing to pin, so pool identifiers are listed,
and `leg.hub` — the manager application, AlgoFi's second caller-supplied
identifier — is pinned to the one they all share.

**The list is a liquidity curation, not the full set.** `router.graph` builds
AlgoFi edges from three files and collapses them by manager, which yields
**470 pools**. A 470-entry list is not usable: 3.7 KB of constant, and up to
470 iterations of `_assert_listed` against the 700 opcode units an application
call is given. The list is therefore every pool holding **at least 100 ALGO**,
measured 2026-08-12 — 23 of the 470. Everything excluded held under 110 ALGO;
the largest two included hold 130,266 and 45,212.

**A leg through any other AlgoFi pool is refused, not traded.** That is a
deliberate loss of a little routing surface in exchange for the contract not
calling an application nobody has looked at. Across the four sweeps to
2026-08-11 the allocator chose an AlgoFi pool 12 times, and it was `605929989`
every time.

A list is acceptable here and nowhere else because AlgoFi shut down. Its SDK is
gone (`router.venues` reads its pools off the chain directly for that reason),
so neither the pool set nor its remaining liquidity is going anywhere.

**How the size of that set was nearly got wrong**, since it bears on the rest
of this document: the first version of this list came from a scan of
`algofi-pools-active.csv` alone, 16 pools, and was documented as exhaustive.
`router.graph` reads three AlgoFi files, not one. The same mistake was made for
Pact and STAMM — the creator scan used `pact-pools.csv` and `stamm-pools.csv`
and missed the `-0` files, which hold the **ALGO-paired** pools and so the ones
that matter most for routing. Rescanned: 655 of the 664 ALGO-paired Pact pools
come from the two pinned creators, the other 9 being the excluded new-generation
factory, and all 7 ALGO-paired STAMM pools come from the pinned one. The
creator pins were right; the evidence for them had a hole.

## Cost

An operational property rather than a trade-off, and the same class as M6: the
pins are compile-time, so if Pact rotates its deployer the constant is stale
until the next deployment. The failure is loud — every Pact route refused — not
silent.

## Verified by

- `tests/test_contract_localnet.py::TestThePoolPins` — a **second stub pool,
  deployed by a different account and stocked with the same reserves**, so the
  only thing wrong with it is who made it. Both pinned providers refuse it, and
  the genuine pool still routes.

  Worth recording how that test first failed: it built the impostor with
  `L.funded_account()`, which returns whichever LocalNet account is *richest*
  and therefore handed back the fixture's own. The impostor was created by the
  address the pin allows, the routes succeeded, and the test failed against a
  contract behaving exactly as intended. A pin test that does not prove the
  impostor is genuinely foreign proves nothing.
- `tests/test_router_contract.py::TestThePoolPinConstants` — the invariants a
  mistyped constant would break. A wrong creator does not fail to compile or to
  deploy; it produces a router that silently refuses every route through that
  provider.
