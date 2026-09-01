# S8 — A hostile transfer rides alongside a genuine route call

- **Severity:** Medium (any holding the account carries; the same precondition
  as `S2`, `S3`, `S6` and `S7` — a hostile or poisoned engine response)
- **Component:** off-chain — `dustsweep.js` `routedGroupProblems`; and the
  contract, which does not constrain group composition either
- **Origin:** review of the `S7` fix, 2026-09-01
- **Status:** **Open.** No complete fix is available in the browser or in the
  contract; §6 records two partial mitigations and why each is partial.

---

## 1. What `S7` fixed, and what it did not

`S7` established that a group labelled `convert` must actually call a guarded
router method — not `pool_budget` or `verify_discount`, which skip the hygiene
guard, but one of the 13 entry points that assert over the group. That makes
the contract's checks *run*.

It says nothing about what else is in the group.

## 2. The defect

Take a real, well-formed conversion group and add one transaction: an `axfer`
sending the user's balance of some asset to an address the attacker controls.
It survives every check in the system.

**The browser.** `routedGroupProblems` refuses a `rekey`, a `close`, an
`aclose` and a group fee over `MAX_GROUP_FEE`, and requires a guarded router
call. The added transfer carries none of the first four, and the guarded call
is present because the rest of the group is genuine.

**The contract's hygiene guard.** `_assert_group_is_clean` walks the whole
group but reads only `rekey_to`, `close_remainder_to`, `asset_close_to` and
`fee`. It never looks at `asset_amount` or `asset_receiver`.

**The router's own logic.** This is the part that was supposed to make the
difference, and it is bound narrowly. `_input_amount` checks exactly one
transaction:

```python
assert payment.sender == Txn.sender, "input must come from the caller"
assert payment.group_index + 1 == Txn.group_index, (
    "input must immediately precede the route"
)
```

The route validates *its* input — the transaction immediately preceding it —
and its own output. A transfer sitting anywhere else in the group is not the
route's input, is never examined, and executes on its own terms.

So `S7` raised the bar without closing the vector: the attacker must now
include a genuine route call, which costs a fee and nothing else.

## 3. Why the browser cannot fix this the way `S7` was fixed

`S7` worked because there was a question the browser could answer without
knowing the route: *is the router in this group?* The natural next question —
*is every transfer going somewhere legitimate?* — it cannot answer.

The obvious rule is that every value-moving transaction sent by the swept
account must have the router's application address as its receiver. Checked
against [evidence/](../evidence/), that rule **refuses a conversion that
executed**:

| group | user's transfers go to |
|---|---|
| `sweep-3-convert` | `GV27MIIS…` ×4 |
| `sweep-4-convert` | `GV27MIIS…` ×3 |
| `sweep-6-convert` | `GV27MIIS…` ×3, **`ZJWF2PLJ…` ×1** |

`GV27MIIS…` is the application address of router `3689591968`. `ZJWF2PLJ…` is
not, and it is not the address of the pool application called in the same group
(`1002541853` → `XSKED5VK…`) either: it is a **pool escrow**, from a leg where
the caller pays the pool directly rather than through the router.

A sweep therefore legitimately pays addresses that are neither the router nor
derivable from anything in the group. Enumerating them means recomputing the
route, which is the engine's job and the reason the browser is not doing it.
The browser also cannot derive an application address at all — that needs
SHA-512/256, which WebCrypto does not offer, the same wall `addressToBytes`
documents.

## 4. Why the contract cannot fix it either

The same table refuses the same rule on chain. A contract-side assertion that
the caller may only pay the application would break the direct-to-pool leg in
`sweep-6-convert`, which is a legitimate and cheaper route shape. The contract
could constrain *its own* routes further, but it cannot forbid a transaction it
is not a party to without forbidding a pattern the router deliberately uses.

## 5. Reachability

Unchanged from `S6` and `S7`: the engine's response must be wrong, through code
compromise or through the Redis asset cache the engine reads without checking.
Given that, this is the residual vector — the one that survives all three
browser rules — and nothing constrains which asset it moves, so it is not
limited to the dust a sweep is nominally about.

Rated Medium on the same reasoning as the others: not reachable by an
unprivileged remote attacker, but it defeats the control built to hold under
exactly these conditions, and the value it exposes is unbounded.

## 6. Recommended mitigations, and why neither is a fix

**1. Bind the moved assets to what the reader was shown.** A conversion group
may only move assets the plan listed with a `convert` disposition for this
address. This is the rule `closeOutProblems` already applies to close-outs, and
it catches the substitution case: a group that quietly moves a valuable holding
the sweep never mentioned.

*Why it is partial.* Both halves come from the same response, so it is
`closeOutProblems`'s bargain rather than `forfeitTargetProblems`'s: it catches
bytes that disagree with the description, not a description that lies
consistently. It does **not** catch the converted asset being sent to the wrong
place, which is the more direct form of this attack.

**2. Show the conversion's destinations before signing.** `S2` recommendation 2
put the forfeit destination in the row; the same disclosure for a conversion
would let a reader see that a group moves a holding somewhere unexpected.

*Why it is partial.* It moves the burden onto the reader, which the `S2`
finding already says is a complement rather than a control. A reader cannot be
expected to recognise a pool escrow address.

**Neither closes it, and this finding stays open on purpose.** The honest
position is that the browser can prove the router is present and cannot prove
the group does nothing else — and that a control which looks complete and is
not would be worse than one documented as partial. That is the mistake `S7`
recorded, one level down.
