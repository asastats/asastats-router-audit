# S8 — A hostile transfer rides alongside a genuine route call

- **Severity:** Medium (any holding the account carries; the same precondition
  as `S2`, `S3`, `S6` and `S7` — a hostile or poisoned engine response)
- **Component:** off-chain — `dustsweep.js` `routedGroupProblems`; and the
  contract, which does not constrain group composition either
- **Origin:** review of the `S7` fix, 2026-09-01
- **Status:** **Fixed, 2026-09-03**, by option B in §8 — the quote signer moved
  to its own service, which now refuses any caller movement paying an address
  the group's own application calls do not make legitimate. §9 records what
  landed, including the two places this finding's own proposed design was
  wrong. Mitigation 1 (§6) shipped separately on 2026-09-02 and remains.
  **Not yet deployed:** the fix is in the code, and the engine holds the
  signing key until the service is provisioned.

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

`GV27MIIS…` was the application address of router `3689591968`, which served
these groups and has since been retired. `ZJWF2PLJ…` is
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

## 7. Confirmed against the shipped code

Not argued. The `S7` fix was run against a real conversion group from
[evidence/](../evidence/) with one `axfer` appended, moving a balance of an
asset the sweep never mentioned to an address of the attacker's choosing:

```
routedGroupProblems(sweep_3_convert,            3689591968)  ->  []
routedGroupProblems(sweep_3_convert + hostile,  3689591968)  ->  []
```

Same verdict either way. The hostile group carries no `rekey`, no `close`, no
`aclose`, a total fee of 60,000 microALGO against a ceiling of 1,000,000, and a
guarded router call — because the rest of it is genuine.

## 8. What a fix would have to be anchored in, and what that rules out

The precondition for `S6`, `S7` and `S8` is a **compromised or poisoned
engine**. That single fact settles more of the design space than it looks like,
and it is worth stating before anyone spends a week on the obvious idea.

**The tempting fix does not work.** The co-signed quote note already commits to
the caller, the asset out, the floor and a per-index input map. Adding the
group size, or a digest of the group, would make an appended transaction break
the signature — a complete fix, cheaply, in a place that already exists.

It fails because of who holds the key:

```python
# engine/core/quote_signer.py, in the same process that builds the group
private_key = _private_key(network, str(signer_key_path(network)))
...
blob = final.sign(private_key)
```

`ROUTER_QUOTE_SIGNER_KEY_TEMPLATE` resolves to a file on the engine's own host
and is read in-process. **An engine that can build a hostile group can sign a
note describing it.** The signer's own `_validate_group` checks group-id
consistency and nothing about composition, so it adds nothing here either.

The same argument disposes of every variant: any commitment the engine
computes, the engine can compute for the attack.

**So the property is narrower than "co-signed" suggests.**
[REPORT §2](../REPORT.md) says the floor is co-signed so that "a compromised
frontend has nowhere to put a zero", and that is exactly right *for a
frontend*. It was never a second opinion against the engine, because the engine
is the co-signer. Nothing in this repository claims otherwise; it is recorded
here because the word invites the stronger reading.

**What survives an engine compromise is short, and it is the whole menu:**

| anchor | already used by | could it close `S8`? |
|---|---|---|
| the wallet's connected account | `closeOutProblems` sender/receiver rules | no — the attack sends *from* that account |
| the chain, read by the bridge | `S2`'s creator lookup | **partly** — see below |
| the deployed contract | `_assert_group_is_clean`, the route's own logic | no — §4 |
| the reader | `destinationLabel` | no — §6 mitigation 2 |

### The two options that are actually open

**A. Teach the bridge to derive the legitimate destinations.** §3 rejects this
on the grounds that the browser cannot compute an application address without
SHA-512/256. That objection is answerable: the *bridge* is TypeScript with
algosdk, already holds an algod client, and already answers `assetCreator`. It
could equally answer "what addresses may this group pay?".

What it cannot cheaply do is enumerate them, and that is the real cost. The
router's application address is one line; a Tinyman v2 pool escrow is a
logic-signature account the contract derives by rebuilding a 47-byte template,
and other providers differ again. This is re-implementing route knowledge in
the wallet, which is a second place to be wrong about something the engine
already knows — and being wrong in the *refusing* direction breaks conversions
that work today.

**B. Move the quote signer off the engine.** A separate signing service, on its
own host with its own key, that re-derives the group from the plan and refuses
to sign one it did not expect. This is the only option that closes `S8`
completely, because it is the only one that makes the co-signature mean what
the word implies: two parties, one compromise not enough.

It is infrastructure, not a patch — a new service, a new key custody
boundary, a new failure mode when it is unreachable — and it needs the group
composition to be derivable from the plan, which it currently is because the
engine builds both.

### What has been done since, 2026-09-02

**Mitigation 1 is taken** — `convertedInputProblems` in the widget. Every
transfer the connected account sends must move an asset the plan named, for no
more than it described. The rule was derived from the seven executed groups
rather than from a model of one: in each, every transfer the holder sends moves
the same asset, split one transfer per venue, and the parts sum to exactly the
described holding.

**Option B is under way and does not yet close this.** The signer now exists as
a service (`router/signer/`) whose key can live under an account the engine
cannot read, and it parses the note the engine's signer only ever measured —
the application, the caller, `asset_out`, the asserting index, each route
call's enumerated amount against the transaction funding it, and an entry
describing a position that holds no route call, which the contract cannot check
because it reads the note one index at a time.

**What it deliberately does not check is why `S8` is still open.** The obvious
rule — that the note's enumeration accounts for every movement the caller makes
— is wrong, and executed traffic proves it. `sweep_6_convert` opens with a
transfer to a Tinyman v2 pool followed by a `swap` call to `1002541853`: a
**direct venue leg**, sent straight to a pool rather than through the router,
which the note does not enumerate and never should. Requiring exhaustiveness
refuses one honest conversion in three of the routed groups in `evidence/`.

Closing this needs **destination** verification — every caller movement must
pay the router's application account or a pool the group's own provider calls
legitimately use — which is option A's expensive part, moved to the one place
it is affordable. That is a separate stage.

## 9. What closed it, 2026-09-03 — and where §8 was wrong

The destination stage landed: `router/signer/venues.py`, wired into
`authorisation_problems`. A movement the note does not enumerate is authorised
only if its receiver is an address **derived** from the group's own application
calls, under the same provider rules the contract applies to the legs it runs:

| provider | how the destination is established |
|---|---|
| Tinyman v1/v2 | the pool is a logic signature, so its address is recomputed from the validator and an asset pair |
| Pact | the pool's creator must be one of `PACT_POOL_CREATORS`; a weighted pool's deposit goes to a vault whose application id the pool's own state names |
| STAMM | creator, as `STAMM_POOL_CREATORS` |
| AlgoFi | membership of the explicit `ALGOFI_POOLS` list |

Nothing there reads a field the group asserts — not `accounts`, not
`foreign_apps`. That distinction is the whole security argument: an attacker
can put any address in a transaction, and cannot make it *be* the Tinyman pool
for a pair or make Pact have created their application. The whitelists moved to
`router/providers.py` so the signer and the compiled contract read one copy.

**§8 was wrong about the design.** It proposed a signer that "re-derives the
group from the plan". That cannot work: reserves move between the engine's
quote and any re-derivation, so the comparison needs a tolerance, and a
tolerance is a hole. The signer needs no plan at all — the note already carries
what the route may spend, and everything else is answered by where it is going.

**§3 was wrong about the cost, in the direction that mattered.** It rejected
enumerating destinations as re-implementing route knowledge. Enumerating them
*in the wallet* would have been; enumerating them beside the contract's own
whitelists is four rules and one cached chain read.

**What proves it refuses nothing honest.** Not the seven groups in `evidence/`,
which are too thin a base for a rule whose failure mode is a broken conversion.
`router/scripts/signer_corpus.py` builds live groups through `group_for_quote`
— the entry point the engine itself calls — across every ordered pair of eight
assets at four sizes, and runs the rule over every unenumerated movement in
each. Every provider is represented. It exits non-zero if one is refused.

**The residual, stated rather than hidden.** The Tinyman derivation pairs over
the assets the group moves for value, so an attacker who first gets the caller
holding a token they created, and then moves a unit of it, can reach a pool
whose liquidity is theirs. That needs a compromised engine *and* an accepted
airdrop, it yields only what a pool pays back rather than the transfer, and
`convertedInputProblems` refuses it independently in the browser.

And the signer still does not judge whether `minimum` is a *fair* floor. The
contract takes it on faith and so does this. A compromised engine can quote a
bad price; it can no longer move the money somewhere else.

### The recommendation, as it stood

**Take mitigation 1 now and decide on B separately.** Binding the moved assets
to what the plan described is cheap, sits in code that already exists, and
catches the substitution case. It does not close `S8` and this finding stays
open when it lands.

**A is not recommended.** The cost is high, the failure direction breaks working
conversions, and it duplicates the engine's own knowledge — which is the
argument `S3`'s abandoned input cap already lost.

**B is the fix, and it is a product decision about operating cost, not an
audit finding.** It is out of this audit's scope for the same reason key
management is, and it is named here so the decision is taken deliberately
rather than by not taking it.
