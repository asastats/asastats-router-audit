# S6 — The conversion path is checked by nothing the engine does not choose

- **Severity:** Medium (entire holdings and ALGO balance; requires a hostile or
  poisoned engine response — the same precondition as `S2` and `S3`)
- **Component:** off-chain — `dustsweep.js` `signAction`; `swapBridge.ts`
  `signAndSendPartial`
- **Partly a contract matter.** `_assert_group_is_clean` would refuse the
  groups described here, but only if it ran, and nothing off-chain makes it run.
- **Origin:** review of the `S2`/`S3` fix, 2026-09-01
- **Status:** **Fixed** — `routedGroupProblems` in the widget; see §8

---

## 1. Why this was not visible while `S2` was being fixed

`S2` and `S3` are both findings about the close-out path, and the fix for both
lives in `closeOutProblems` and `forfeitTargetProblems`. The reasoning that
justified leaving the conversion path alone is written into `signAction`'s own
docstring:

> Only the close-out path is inspected here — a conversion carries a router
> call the contract itself checks, including its refusal of any group
> containing a close.

That sentence is true of every conversion the honest engine builds. It is not
a property of the code, and the difference is the finding.

## 2. The defect

`signAction` dispatches on `action.kind` before any inspection happens:

```js
async function signAction(action, address, bridge) {
  if (action.kind === "convert") {
    if (typeof bridge.signAndSendPartial !== "function") {
      throw new Error("The connected wallet does not support quote-signed groups");
    }
    return await bridge.signAndSendPartial(partialGroup(action));
  }

  var problems = closeOutProblems(action.transactions, address, action.holdings);
```

`action.kind` arrives in the same JSON response as `action.transactions`. It is
the engine's word, and it decides whether the whitelist runs at all. This is
the same shape as `S2` — a control anchored inside the response it is meant to
check — moved up one level: `S2` was a *reference value* the engine supplied,
and this is the *switch* that selects whether any checking happens.

The `S2` fix hardened the door. This is the second door, and it has no lock the
engine does not hold the key to.

## 3. Why the contract does not close it

`_assert_group_is_clean` is real and it is strong. It walks every transaction
in the group and refuses a rekey, a `close_remainder_to`, an `asset_close_to`,
and a total fee over `MAX_GROUP_FEE`:

```python
for index in urange(Global.group_size):
    transaction = gtxn.Transaction(index)
    assert transaction.rekey_to == Global.zero_address, "this group rekeys an account"
    assert transaction.close_remainder_to == Global.zero_address, "this group closes an account"
    assert transaction.asset_close_to == Global.zero_address, "this group closes a holding"
    paid += transaction.fee

assert paid <= MAX_GROUP_FEE, "this group overpays the network"
```

It is called from 13 of the contract's 15 entry points (the two that skip it,
`pool_budget` and `verify_discount`, are permissionless, write no state and
send nothing — they ride alongside a `route` call that sweeps the group).

**But an assertion inside an application can only run if the application is
called.** The contract cannot refuse a group it is not in. `SWEEP-REPORT.md` §1
and `S3` §7 both already say this about close-out groups — *"a close-out group
carries no application call, so `_assert_group_is_clean` never runs over it"* —
and treat it as the structural reason the widget check had to exist. The same
sentence is true of any group the engine labels `convert`, and there the widget
check does not exist either.

Nothing on the client requires a `convert` group to contain a router call:

| where | what it checks about the group's contents |
|---|---|
| `signAction`, convert branch | nothing |
| `partialGroup` | decodes base64; reads `quote_signer_index` |
| `signAndSendPartial` (`swapBridge.ts:210`) | quote authorisation is the **final** transaction; each backend blob decodes to bytes identical to its grouped entry; the blob carries a signature; every transaction has a `group` id |
| `_assert_group_is_clean` | everything — **if the group calls the router** |

## 4. The quote signature is not a second opinion

`signAndSendPartial` refuses a group whose backend-signed transaction does not
match the grouped bytes, and refuses one where that signature is missing. That
is a real integrity check, and against a *tampered* response it holds.

It is not a check against a *hostile* one. The key that produces that signature
is `quote_signer`, and the engine holds it — that is what makes it the engine's
quote authorisation. Under the threat model `S2` and `S3` are written against
(*"needs the engine's response to be wrong — through code compromise, or
through the Redis asset cache the engine reads without checking"*), an attacker
who can choose the response can also sign the transaction that authorises it.
The signature proves authorship, not safety.

## 5. Reachability

The precondition is exactly `S2`'s and `S3`'s, and no worse: the engine's
answer must be wrong. Given that, the group need not be clever. A response of

```json
{"kind": "convert", "transactions": ["<axfer, asset_close_to = attacker>", "<quote auth>"],
 "quote_signer_index": 1, "signed_transactions": {"1": "<engine-signed>"}}
```

contains no application call, so no contract assertion runs; passes
`signAndSendPartial`, whose four structural rules it satisfies; and reaches the
wallet, where the user sees a two-transaction group in the same prompt shape
they have approved before. A `pay` with `close_remainder_to` in the same group
takes the ALGO balance as well — the shape `closeOutProblems` refuses first and
most loudly on the other path, and that nothing examines on this one.

This is *not* reachable by an unprivileged remote attacker, and it should be
rated the same Medium as `S2` and `S3` for the same reasons given in
`SWEEP-REPORT.md` §2: it defeats a control built to hold under precisely these
conditions, and the value it exposes is unbounded.

## 6. Why the tests did not catch it

`dustsweep.test.js` covers the convert path twice — that it routes to
`signAndSendPartial`, and that a wallet lacking that method is told so:

```js
test("a conversion goes through the quote-signed path", async () => {
  // It carries the engine's quote authorisation, which `signAndSend` would
  // destroy by re-assigning group ids.
```

Both assert the routing, which is correct and is the behaviour that comment
explains. Neither asserts anything about the group's *contents*, because on
this path there is no rule about the contents to assert. The property tests
added in `d1365dc` generate malformed `holdings`, which the convert branch
never reads.

This is the third instance of the pattern `S1` and `S2` both ended on: the
suite proves the half that works.

## 7. Recommended fix

**Mirror `_assert_group_is_clean` in the browser, on the convert path.** The
widget already has the decoder, and the rule already exists in an audited,
deployed form — so mirroring it cannot refuse a group the contract would
accept:

- no transaction carries `close` (`pay`) or `aclose` (`axfer`)
- no transaction carries `rekey`
- the group's total `fee` is at most `MAX_GROUP_FEE` (1,000,000 microALGO)

That is unconditional, where the contract's copy is conditional on the group
calling the router, and it makes `action.kind` stop being a security decision:
whichever branch is taken, closes and rekeys are refused.

**One risk worth naming, because it is on the revenue path.** `decodeMsgpack`
reads the msgpack subset a *close-out* uses. A router group carries application
calls — `apaa` argument arrays, `apat`/`apas` foreign arrays, notes — which are
larger and more varied. Canonical encoding uses the smallest tag that fits, so
a transaction under 64 KiB should stay inside the supported set, but "should"
is doing work in that sentence. **This should not ship without exercising it
against real router groups.**

---

## 8. As delivered

`routedGroupProblems`, applied to `action.transactions` in `signAction`'s
convert branch before anything reaches `signAndSendPartial`. It mirrors
`_assert_group_is_clean` field for field — no `rekey`, no `close`, no `aclose`,
and a group fee total against `MAX_GROUP_FEE`, carrying the contract's own
1,000,000 rather than a number chosen here. Mirroring cannot refuse a group the
contract would accept; what the copy buys is that it *runs*, whatever the
response calls the group. `action.kind` still selects the branch and no longer
decides whether checking happens.

**The decoder risk in §7 was settled with evidence, not reasoning.** The seven
groups in [evidence/](../evidence/) were re-encoded from what the indexer
returned and run through the shipped `decodeMsgpack`: **97 of 97 decode**,
application calls included. The tags real traffic uses are `fixmap`,
`fixarray`, `fixstr`, `bin8` and `uint16/32/64` — every one already supported,
with no `map16`, `bin16/32` or anything outside the set. Those 97 transactions
are now a test fixture (`tests/javascript/mainnet-groups.json`), so the honest
side of this rule is tested against traffic that executed rather than against
fixtures written to pass. A transaction that will not decode is refused rather
than skipped, so a tag that does turn up costs one conversion instead of
passing one through.

**The ceiling has fourteen times the headroom it needs.** Measured on the same
groups: the dearest thing that has executed is a 13-transaction swap paying
71,000 microALGO, and the three convert groups pay 43,000, 60,000 and 43,000.
None carries a close or a rekey, which is what the guard asserts.

**It found something on the way in.** The example suite's "a conversion goes
through the quote-signed path" passed `[CLOSE_TO_SELF]` as its group — a
stand-in chosen because the path did not look at it. The new rule looked, and
refused it. The test now uses a real convert group; a test whose fixture the
production rule rejects was proving less than it appeared to.

**The related hang is closed too.** `CREATOR_LOOKUP_TIMEOUT` bounds the `S2`
creator lookup at ten seconds and resolves to `null` on expiry, so a node that
never answers joins the unreachable node and the unreadable asset instead of
leaving the reader on a spinner with no prompt and no error. algosdk v3's
client sets no timeout of its own; this was the one failure on that path that
neither refused nor accepted.

Ten checks in [verify-sweep.sh](../verification/verify-sweep.sh) cover this
section. They asserted the gap while the finding was open and assert the fix
now.
