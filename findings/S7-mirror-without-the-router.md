# S7 — The mirrored guard copied the cheap half and left the load-bearing one

- **Severity:** Medium (any holding the account carries; the same precondition
  as `S2`, `S3` and `S6` — a hostile or poisoned engine response)
- **Component:** off-chain — `dustsweep.js` `routedGroupProblems`
- **Origin:** review of the `S6` fix, 2026-09-01
- **Status:** **Fixed** — the guarded-router-call rule; see §6

---

## 1. What `S6` fixed, and what it did not

`S6` closed the hole where `signAction` decided whether to inspect a group by
reading `action.kind` from the engine's own response. The fix mirrors the
contract's `_assert_group_is_clean` in the browser, so the rule runs whatever
the response calls the group:

- no transaction carries `rekey`
- no transaction carries `close` or `aclose`
- the group's total fee is at most `MAX_GROUP_FEE`

Every one of those is **hygiene**. And hygiene is not what a hostile conversion
group has to violate.

## 2. The defect

A group labelled `convert`, containing one ordinary asset transfer of the
user's whole balance to an address the attacker controls:

- carries no `aclose` — it is a transfer, not a close-out
- carries no `close` — it is an `axfer`, not a `pay`
- carries no `rekey`
- pays an ordinary fee

It passes `routedGroupProblems` completely. The mirror was drawn faithfully and
it does not object, because **the contract's guard does not object either** —
`_assert_group_is_clean` never looks at `aamt` or `arcv`.

It does not have to. On a routed group the *rest of the contract* looks: the
input proven spent by `_assert_input_spent`, the floor authenticated by
`_signed_floor`, the pairwise-distinct assets, the pool applications pinned by
`app_creator`. Hygiene is the cheap outer shell around that, and the shell was
the only part copied.

**So `S6`'s fix reproduced the half of the contract's protection that was never
the point, and left out the half that was.** The two exempt entry points make
the same argument from the other side: `pool_budget` and `verify_discount` skip
the hygiene guard precisely because they ride alongside a `route` call — the
contract's own reasoning is that hygiene alone is not what makes a group safe.

## 3. Why the browser cannot simply check more

The obvious repair — have the widget validate the transfer — does not exist.
A conversion legitimately sends the input asset away from the user; that is the
whole operation. The destination is a pool or the router's escrow, chosen by a
route the browser did not compute and cannot recompute. There is no whitelist
of receivers to write, and no amount to compare against.

What the browser *can* determine is whether the party that **can** check is in
the group at all.

## 4. Why "calls the router" is not the rule either

Requiring an application call to the router application would be nearly right
and quietly wrong. `pool_budget` and `verify_discount` are router calls that
skip the hygiene guard and validate nothing:

```
[ pool_budget(router) , axfer(user → attacker) ]
```

calls the router, satisfies a naive rule, and is checked by nothing. The rule
has to require a router call that is **not** one of those two — one of the 13
entry points that assert over the group.

## 5. Reachability

Identical to `S6`: the engine's response must be wrong, through code compromise
or through the Redis asset cache the engine reads without checking. Given that,
this is the more direct attack of the two — it does not need a close-out at
all, and nothing constrains which asset it moves, so it is not limited to the
dust a sweep is nominally about.

Rated Medium for the reason the other three are: it defeats a control built
specifically to hold under these conditions, and the value it exposes is
unbounded.

## 6. As delivered

`routedGroupProblems` now also requires that the group contain an application
call to the router whose ARC-4 selector is not one of the two budget-only
methods. Both halves are kept: hygiene refuses a close or a rekey immediately
and legibly, and the router rule ensures the on-chain checks that refuse
everything else actually run.

**Where the application id comes from is the point.** It is handed down as
`data-router-app` from `DustSweepView.get_context_data`, overridable by a
`ROUTER_APP_ID` setting, with the same number carried in `dustsweep.js` as a
fallback so a missing attribute cannot switch the rule off. It is **not** read
from the plan response — an id the engine supplied would make the check agree
with whatever the engine wanted, which is `S2` restated for the third time.

**The two excluded selectors are recomputed, not copied.**
`verify_discount(byte[])void` → `93a1b819`, `pool_budget()void` → `9e57d62c`,
SHA-512/256 of the signature, first four bytes. `verify-sweep.sh` derives them
from the signatures and compares against the widget, so a wrong constant fails
the audit rather than silently degrading the rule to "any router call counts".

**Checked against traffic, again.** All four router groups in
[evidence/](../evidence/) — three sweep conversions and one swap — contain
router calls with non-exempt selectors (`L40oXg==`, `483vOw==`, `8MM54A==`), so
the rule accepts every conversion that has actually executed. `pool_budget`
appears in all four as well, which is exactly why it could not be allowed to
count on its own.

**It caught a test that had gone quiet.** The property "accepting implies no
transaction closes or rekeys" became vacuous the moment this rule landed: no
corpus transaction is an application call, so every generated group was refused
for that reason alone and the implication was never exercised. It now prefixes
a real `route` call from an executed group and asserts that some generated
group really was accepted, so the property tests what it claims to.

Seven checks in [verify-sweep.sh](../verification/verify-sweep.sh) cover this
section.
