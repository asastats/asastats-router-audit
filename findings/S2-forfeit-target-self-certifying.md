# S2 — The browser whitelist does not bind the forfeit destination

- **Severity:** Medium (defeats the stated purpose of the control; requires a
  hostile or poisoned engine response)
- **Component:** off-chain — `dustsweep.js` `closeOutProblems`
- **Not a contract defect.** A close-out group carries no application call.
- **Origin:** this audit
- **Status:** Open

---

## 1. The control and what it claims

A close-out group is up to sixteen transactions approved with one click, and
`asset_close_to` moves an entire holding. The router contract cannot help:
these groups contain no application call for `_assert_group_is_clean` to
refuse. So the widget decodes the group in the browser and checks it before it
reaches the wallet. Its own module docstring sets the standard:

> Not because the engine is expected to lie, but because "the engine said so"
> is the only other assurance on offer, and **a control that consists of
> trusting the thing it is meant to check is not a control**.

And `closeOutProblems` states what the destination rule buys:

> the close target is the one the plan named for that asset [...] **This is
> what makes the check bind rather than merely restate the response.**

## 2. The defect

The reference value for a forfeit's destination comes from the same HTTP
response as the bytes it is checked against:

```js
var expected = {};
(described || []).forEach(function (one) {
  // an empty holding closes to itself; a forfeit closes to the creator
  expected[one.asset] = Number(one.amount) === 0 ? address : one.creator;
});
```

`described` is `action.holdings` — the `holdings` array of the plan. The bytes
are `action.transactions` of the same plan. **An engine that sets both
consistently is unconstrained**, and chooses the destination of every forfeit.

Splitting the rules by what they are anchored to makes the gap exact:

| rule | anchored to | binds? |
|---|---|:---:|
| `type` is `axfer` | the shape itself | yes |
| `aamt` is zero | the shape itself | yes |
| no `rekey` | the shape itself | yes |
| `aclose` is present | the shape itself | yes |
| `snd` is the holder | **the wallet's active account** | yes |
| `arcv` is the holder | **the wallet's active account** | yes |
| `xaid` was listed | the plan's own `holdings` | no |
| `aclose` for an **empty** holding | **the wallet's active account** | yes |
| `aclose` for a **forfeit** | the plan's own `holdings` | **no** |

Everything anchored outside the response holds. The one field that decides
where a user's tokens go is anchored inside it.

The Django endpoint in front of the engine does not narrow this: it forwards
the engine's answer verbatim (`return JsonResponse(answered)`), adding only the
gating of `address`.

## 3. Demonstrated

Three well-formed close-out groups built with algosdk, run through the shipped
`closeOutProblems` unmodified — `verification/verify-sweep.sh`, case 1:

```
--- honest ---
  closes to    : creator
  problems     : (none)
  VERDICT      : ACCEPTED by the whitelist
--- tampered ---
  closes to    : attacker
  problems     : (none)
  VERDICT      : ACCEPTED by the whitelist
--- tampered bytes, honest description ---
  problems     : transaction 1 closes asset 31566704 to an unexpected address
  VERDICT      : refused
```

The third case is the control, and it is what the whitelist genuinely does: it
catches a response that **contradicts itself**. A consistent one walks through.

## 4. Why the bar is lower than "compromise the engine"

The destination is a cache read. `_asset_facts` takes the creator from
`carrier.asset_info(asset)`, and with `USE_CACHED_NODE_DATA` — which defaults
to `"true"` — that is a Redis `hget` against `a:<asset_id>`, msgpack-unpacked
and used, with no comparison against the chain:

```python
if not skip_cache and settings.USE_CACHED_NODE_DATA:
    data = cached_asset_hash_info(asset_id, self.cache_client)
```

So write access to one Redis hash field redirects every forfeit of that asset,
and the browser check confirms it. Cache poisoning is precisely the class of
failure an independent browser-side control exists to catch — and the module
docstring names "a cached answer" among the things it catches.

## 5. Why the tests did not catch it

`dustsweep.test.js` passes 121 tests at **100% line and branch coverage** of
`dustsweep.js`. The test that appears to cover this is:

```js
test("the right asset closed to the wrong address", () => {
  // Asset 5 was described as an empty holding, so it must close to self.
  const problems = sweep.closeOutProblems(
    [FORFEIT_TO_CREATOR], ADDRESS, [{ asset: 9, amount: "0", creator: CREATOR }]
  );
  expect(problems).toEqual(["transaction 1 closes asset 9 to an unexpected address"]);
});
```

`amount: "0"` selects the **empty-holding** branch, whose expected target is
`address` — the one anchored to the wallet. The test proves the branch that
binds, and is correct. No test varies the creator while letting the description
follow it, because that case passes.

Coverage measures which lines ran, not which claims were tested. This is the
same shape as [`I2`/`S1`](S1-unpriced-forfeit.md): a control certified by tests
that exercise the half that works.

## 6. Recommended fix

The check needs a reference for the creator that does not come from the plan.

1. **Resolve the creator independently in the browser.** The wallet bridge
   already holds an algod client and already uses it for
   `accountAssetInformation` in `isOptedIn`. Exposing `assetCreator(id)` on the
   bridge and comparing `aclose` against *that* would make the forfeit rule as
   well-anchored as the sender rule. One request per distinct forfeited asset,
   on a path that already makes network calls.

2. **Show the destination.** The row renders unit, id, badge, value and reason,
   but never the address the tokens go to. A reader cannot check against the
   wallet prompt what they were never shown. This is cheap and worth doing
   whatever else changes, but it is a complement to (1), not a substitute — it
   moves the burden onto the reader.

Until one of these lands, the honest statement is that the whitelist binds the
*sender*, the *shape*, and the *empty-holding* destination, and restates the
engine for the forfeit destination. The docstrings should say so.
