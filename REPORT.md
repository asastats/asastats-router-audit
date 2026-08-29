# ASA Stats Smart Router — Security Audit

**Target** `router/contracts/router_app.py` — 2,391 lines of Algorand Python,
compiling to 4,681 lines of TEAL v11 under PuyaPy 5.9.0
**Revision** `8d130d6`
**Deployments** mainnet `3688554446` (restricted) · testnet `770123816`
**Date** 2026-08-29
**Method** AI-assisted review, verified against the source and the chain. See
[DISCLAIMER.md](DISCLAIMER.md) for what that is worth and what it is not.

---

## 1. Verdict

**No critical or high-severity vulnerability was found in the contract.** The
23 findings raised by the five previous audits are closed, and each mitigation
was re-derived from the source rather than carried forward from the earlier
reports — 27 mechanical checks, all passing, in
[verification/RESULTS.md](verification/RESULTS.md).

**This is not a clearance for unrestricted public deployment**, and the reason
has nothing to do with the findings:

> Every audit of this contract, this one included, has been produced by an AI
> system. None has been reviewed by a human with Algorand experience. Mainnet
> `3688554446` is compiled with `RESTRICT_TO_ADMIN` and should stay that way
> until one has been.

That is not boilerplate caution. Two of the five prior audits recommended
removing exactly that restriction, and **both recommendations rested on a
false statement of fact** — v4 cited a testnet application id as though it were
mainnet; v5 recorded the restriction as already removed when it never was.
Neither error would have survived a reader who checked. See
[history/](history/).

### What changed as a result of this audit

One real defect, in the off-chain sweep planner rather than the contract:

| | |
|---|---|
| `S1` | An unpriced holding could be forfeited to its creator with **no value test of any kind** |

Found by reading the predicate that v5 marked "verified safe" without reading
it. Fixed in `1c128f2` / `e13841f`. Full detail in
[findings/S1-unpriced-forfeit.md](findings/S1-unpriced-forfeit.md).

---

## 2. What this contract is

A router that executes multi-hop swaps across four Algorand AMMs — Tinyman v2,
Pact (constant-product, stableswap and managed weighted pools), STAMM, and
AlgoFi — inside one atomic group. It holds no user balances between groups and
carries no permanent inventory.

Four properties do most of the security work:

1. **Output is measured, never trusted.** The contract reads its own holding
   before and after each leg (`asset_holding_get`) and carries the realised
   delta into the next one. A pool that lies about its return value cannot
   move the number the floor is checked against.
2. **The floor is co-signed.** `minimum_received` is not a parameter. It
   arrives in the note of a `pool_budget()` call sent by `quote_signer`, so the
   AVM authenticates it before the contract reads a byte. A compromised
   frontend has nowhere to put a zero.
3. **Inner transactions pay no fee.** Every `itxn` sets `fee = 0`; the group's
   fee is pooled onto the caller's own transaction. The application's balance
   cannot be drained by routing.
4. **Inventory is transient.** Holdings are opened and closed inside the group
   that uses them, returning the 0.1 ALGO minimum balance immediately.

---

## 3. Access control

Derived mechanically from the source, not read off by eye:

| method | admin | restricted | group hygiene | other |
|---|:---:|:---:|:---:|---|
| `set_admin` | ✓ | | ✓ | |
| `set_escrow` | ✓ | | ✓ | |
| `set_fee` | ✓ | | ✓ | ≤ `MAX_FEE_BPS` (100) |
| `set_voucher_signer` | ✓ | | ✓ | |
| `set_quote_signer` | ✓ | | ✓ | |
| `set_conversion_pool` | ✓ | | ✓ | |
| `convert_and_distribute` | ✓ | | ✓ | pool from state |
| `delete_application` | ✓ | | ✓ | accrued must be 0 |
| `close_holding` | ✓ | ✓ | ✓ | |
| `route` | ✓ | ✓ | ✓ | signed floor |
| `route3` | ✓ | ✓ | ✓ | signed floor |
| `opt_in_asset` | | | ✓ | must serve a route |
| `verify_discount` | | | — | ed25519 voucher |
| `pool_budget` | | | — | |

"restricted" is the compile-time `RESTRICT_TO_ADMIN` template variable, set on
every mainnet deployment to date and unset on testnet.

### 3.1 The two entry points that do not assert group hygiene

`verify_discount` and `pool_budget` are the exception, and deliberately.
Neither writes state, sends an inner transaction, or returns a value; both
exist only to add opcode budget and to authenticate a voucher. `pool_budget`'s
own docstring gives the reason a second sweep would be actively harmful: it
would spend part of the very allowance the call exists to add.

The property that makes this sound is atomicity. Any group that *does*
anything runs `route`, `route3` or an admin method, and each of those asserts
hygiene over the **whole group** — so a rekey sitting beside a `pool_budget`
call is refused by the route, and a group with no route does nothing worth
protecting. Verified: 14 entry points, 12 in-body guards, and the guard checks
`rekey_to`, `close_remainder_to` and `asset_close_to` against the zero address.

---

## 4. Findings

All 23 findings from v1–v5 are closed. The six that carry the most weight were
re-verified line by line; the table below is the summary, and
[findings/](findings/) has one file each.

| id | severity | what it was | closed by |
|---|---|---|---|
| `C1` | Critical | permissionless `convert_and_distribute` drained accrued fees | admin gate; pool read from state; same-group approval refused |
| `H1` | High | a frontend could pass `minimum_received = 0` | floor removed from the signature; `_signed_floor` reads a co-signed note |
| `M1` | Medium | route paths not checked for repeated assets | pairwise-distinct assertions |
| `M2` | Medium | funding transaction adjacency not enforced | `payment.group_index + 1 == Txn.group_index` |
| `M3` | Medium | pre-held ASA input not proven spent | `_assert_input_spent` |
| `M4` | Medium | caller could name any pool application | Pact/STAMM pinned by `app_creator`; AlgoFi whitelisted; Tinyman derived |
| `M5` | Medium | caller could request unbounded STAMM opups | `≤ MAX_STAMM_OPUPS`, and `== 0` for non-STAMM legs |
| `M6` | Medium | conversion pool could be approved and used in one group | `_assert_no_conversion_pool_approval` |
| `M7` | Medium | MWPT asymmetric weight quoting drift | exact off-chain math |
| `L1`–`L7`, `I1`–`I7` | Low / Info | see [findings/](findings/) | |

### 4.1 The one that was not closed, and now is

`S1` — the dust sweep's forfeit path. A holding classified `UNPRICED` could be
closed out to the asset's creator whenever the caller opted it in, with **no
test of what it was worth**:

```python
or (one.disposition == UNPRICED and one.asset in opted_in and one.creator)
```

"Unpriced" is a statement about the router's price cache, not about the asset.
On the audited revision, a liquid staking placeholder had evicted every real
xALGO and tALGO pool from that cache, so both assets were unpriced and both
carry a creator. Live data from the same day: an asset the account evaluation
valued at **245.88 ALGO** classified as unpriced and was, until the fix, one
tick away from being given away.

Fixed by a veto — an asset the evaluation priced cannot be forfeited whatever
the caller asks for. It removes candidates and never adds one.

---

## 5. What this audit did **not** verify

Stated plainly, because an audit's silences are where the risk lives.

- **No formal verification.** No proof of the invariants in
  [methodology/](methodology/); they are asserted and tested, not proved.
- **No economic or MEV modelling.** Sandwich resistance rests on the co-signed
  floor. Whether the floor is *well chosen* is a property of the off-chain
  quoter, which this audit does not evaluate.
- **No provider-contract review.** Tinyman, Pact, STAMM and AlgoFi are trusted
  to behave as their interfaces describe. The router's defence against them
  misbehaving is the measured delta and the floor, not an understanding of
  their code.
- **No key-management or operational review.** Admin key custody, signer
  rotation and deployment procedure are out of scope.
- **No live adversarial testing** against mainnet.
- **The AlgoFi whitelist is a list**, and a list is a maintenance commitment.
  23 pool identifiers are compiled in; a pool that is not on it is unreachable,
  and one that should not be on it is reachable until a redeploy.

---

## 6. Static analysis

Tealer, 4,681 TEAL lines, revision `75087b8`. Detail in
[tools/tealer.md](tools/tealer.md).

| detector | result | reading |
|---|---|---|
| `unprotected-updatable` | 9 paths | false positive — `UpdateApplication` appears **0** times in the program |
| `unprotected-deletable` | 9 paths | true and deliberate — admin-guarded `delete_application` |
| `can-close-account`, `can-close-asset` | 0 | clean |
| `constant-gtxn`, `self-access`, `sender-access` | 0 | clean |
| `group-size-check` | vacuous | every group access is dynamic, so the predicate is false on every path |
| `clear-*` (three) | 1 each | the clear program is `pushint 1; return` |

The two HIGH results were re-proven against this build rather than inherited:
`grep -c UpdateApplication` returns 0, so every reported path leads to
something that cannot happen. The single `RekeyTo` in the program is a *read*
inside `_assert_group_is_clean`, not a set.

---

## 7. Reproducing this

```bash
git clone <this repository>
cd asastats-router-audit/verification
ROUTER=/path/to/router ./verify.sh
```

27 checks, no node and no credentials required. If a claim in this report is
not covered by that script, treat it as unverified and tell us.
