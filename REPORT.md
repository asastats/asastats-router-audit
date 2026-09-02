# ASA Stats Smart Router — Security Audit

**Target** `router/contracts/router_app.py` — 2,391 lines of Algorand Python,
compiling to TEAL v11 under PuyaPy 5.9.0
**Revision** `8d130d6`, re-verified at `a6b9df6`
**Deployments** mainnet `3692588382` (**unrestricted**, 5 bps) · testnet
`770893297` (unrestricted, 0 bps). Their predecessors, `3689591968` and
`770729651`, are retired and destroyed, as are `3688554446` and
`770123816`, are retired and destroyed.
**Date** 2026-08-29, revised 2026-09-01
**Method** AI-assisted review, verified against the source, the chain, and
seven groups that executed on mainnet. See [DISCLAIMER.md](DISCLAIMER.md) for
what that is worth and what it is not.

---

## 1. Verdict

**No critical or high-severity vulnerability was found in the contract.** The
23 findings raised by the five previous audits are closed, and each mitigation
was re-derived from the source rather than carried forward from the earlier
reports — 39 mechanical checks, all passing, in
[verification/RESULTS.md](verification/RESULTS.md), and 54 more against
transactions that executed, in
[verification/GROUP-RESULTS.md](verification/GROUP-RESULTS.md).

**This report raised three findings of its own; two are closed and one is
open.**
[`S6`](findings/S6-convert-path-unchecked.md), Medium, off-chain, 2026-09-01:
the dust sweep's conversion path ran no browser check on the group it signed,
and the contract's hygiene guard could not stand in for one because a group
that never calls the contract never reaches it. Fixed by mirroring that guard
in the browser — and then [`S7`](findings/S7-mirror-without-the-router.md),
because that mirror copied the hygiene half of the guard, which is not the half
that refuses a plain transfer to a stranger. Nothing in the contract changed
for either. Reviewing `S7` in turn produced
[`S8`](findings/S8-transfer-alongside-a-route.md), which is **open**: a
transfer added to an otherwise genuine routed group is examined by nothing,
because `_input_amount` binds only the transaction immediately preceding the
route and the hygiene guard never reads an amount or a receiver. It is not
closable by a receiver whitelist on either side — a sweep legitimately pays
pool escrows — so it stays open with partial mitigations rather than a fix that
would look complete. Nothing in the contract changed for any of the three. See
§3.1 and §4.0.

**This is still not a clearance for unrestricted public deployment**, and the
reason has nothing to do with the findings:

> Every audit of this contract, this one included, has been produced by an AI
> system. None has been reviewed by a human with Algorand experience.

That is not boilerplate caution. Two of the five prior audits recommended
removing `RESTRICT_TO_ADMIN`, and **both recommendations rested on a false
statement of fact** — v4 cited a testnet application id as though it were
mainnet; v5 recorded the restriction as already removed when it never was.
Neither error would have survived a reader who checked. See
[history/](history/).

### The restriction came off on 2026-08-30, and this report did not ask for it

The first revision of this document opened by saying mainnet was restricted to
its admin and should stay that way. `3689591968` was deployed the following
afternoon with `RESTRICT_TO_ADMIN` off. **The audit's position has not
changed**, and it is worth being exact about what did:

- The deployment was not made on this report's recommendation. It was made
  after the two mechanisms this report asked for existed —
  [`set_paused`](contracts/going-unrestricted.md) and the group fee bound from
  [`S3`](findings/S3-unbounded-fee.md) — and the pause was pressed on mainnet,
  in both directions, before it was trusted.
- The gap the report named is still open: no human with Algorand experience has
  read this contract. While the admin was the only caller that gap was
  tolerable. It is now the whole question.
- What bounds it is duration rather than analysis. `set_paused` stops routing
  in one transaction and does not depend on any of this being correct.

The evidence that the restriction is off is not the manifest. It is
[four mainnet groups that routed from an account which is not the
admin](evidence/) — the same class of fact v4 and v5 each got backwards from
prose, now answered by a script.

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
| `set_paused` | ✓ | | ✓ | stops `route`/`route3` only |
| `convert_and_distribute` | ✓ | | ✓ | pool from state |
| `delete_application` | ✓ | | ✓ | accrued must be 0 |
| `close_holding` | ✓ | ✓ | ✓ | |
| `route` | ✓ | ✓ | ✓ | signed floor; refused while paused |
| `route3` | ✓ | ✓ | ✓ | signed floor; refused while paused |
| `opt_in_asset` | | | ✓ | must serve a route |
| `verify_discount` | | | — | ed25519 voucher |
| `pool_budget` | | | — | |

"restricted" is the compile-time `RESTRICT_TO_ADMIN` template variable. It is
**off** on `3692588382` and on testnet `770893297`, and was set on every
mainnet deployment before them. The manifest records
`"RESTRICT_TO_ADMIN": 0`; `verify.sh` reads that file rather than describing
it, and [evidence/](evidence/) shows the column empty on chain.

### 3.1 The two entry points that do not assert group hygiene

`verify_discount` and `pool_budget` are the exception, and deliberately.
Neither writes state, sends an inner transaction, or returns a value; both
exist only to add opcode budget and to authenticate a voucher. `pool_budget`'s
own docstring gives the reason a second sweep would be actively harmful: it
would spend part of the very allowance the call exists to add.

The property that makes this sound is atomicity. Any group that *does*
anything **through this contract** runs `route`, `route3` or an admin method,
and each of those asserts hygiene over the **whole group** — so a rekey sitting
beside a `pool_budget` call is refused by the route. Verified: 15 entry points,
13 in-body guards, and the guard checks `rekey_to`, `close_remainder_to` and
`asset_close_to` against the zero address, plus the group's total fee against
`MAX_GROUP_FEE`.

**The qualifier matters, and a later review found where.** "A group with no
route does nothing worth protecting" is true of this contract's own float. It
is not true of the signer's account, which is what the guard exists to defend —
a group with no application call at all can still carry a close-out or a rekey
the user signs. The contract cannot refuse a group it is not in. That is the
stated reason the dust sweep's close-out path needed a browser control of its
own, and [`S6`](findings/S6-convert-path-unchecked.md) is the discovery that
the sweep's **conversion** path has neither: `signAction` decides whether to
run the browser check by reading `action.kind` from the engine's own response,
and takes an unchecked branch for `convert`. Off-chain, and not a contract
defect — but it is the case this section's reasoning did not cover, and it is
recorded here so the next reader does not re-derive the same comfort. The
browser now carries a copy of this guard for exactly that reason.

The seven groups in [evidence/](evidence/) show the separation this forces:
none of the four carrying a router call contains a top-level `asset_close_to`,
and the sweep's 47 close-outs all live in groups with no application call at
all — which is exactly why the sweep needed a browser control of its own.

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

### 4.0 The three this report raised, and where they stand

[`S6`](findings/S6-convert-path-unchecked.md) — **Medium, off-chain, fixed.**
Raised on 2026-09-01 by reviewing the fix for `S2`/`S3` rather than by doubting
it: that fix is sound on the path it covers, and the wallet bridge's
`assetCreator` genuinely resolves a forfeit destination from algod and fails
closed on every way the lookup can fail. What the review found sat one level
up, in which branch ran at all.

Closed by mirroring `_assert_group_is_clean` in the browser, carrying this
contract's own `MAX_GROUP_FEE` rather than a number chosen off-chain, so that
`action.kind` no longer decides whether a group is inspected. **No contract
change was needed or made.** The mirror was checked against the 97 transactions
in [evidence/](evidence/): all 97 decode, and the dearest group that has
executed pays 71,000 microALGO against the 1,000,000 ceiling. See §3.1 for why
the contract could not close this itself.

[`S7`](findings/S7-mirror-without-the-router.md) — **Medium, off-chain, fixed.**
The mirror `S6` added was faithful and insufficient. `_assert_group_is_clean`
checks hygiene — rekey, close, group fee — and hygiene is not what a hostile
conversion violates: a plain transfer of the user's balance to a stranger
carries none of those. What refuses that on a real routed group is the rest of
this contract, `_assert_input_spent` and `_signed_floor` and the pinned pools,
and none of it runs unless the router is called. So the browser now requires
the group to contain a call to a **guarded** entry point — not `pool_budget` or
`verify_discount`, whose exemption in §3.1 exists precisely because hygiene
alone was never the safety argument. The application id is handed down by the
Django view rather than read from the plan.

[`S8`](findings/S8-transfer-alongside-a-route.md) — **Medium, open.** `S7`
makes a conversion group prove this contract is in it. Nothing makes it prove
the group does nothing else, and `_input_amount` binds only the transaction
immediately preceding the route:

```python
assert payment.group_index + 1 == Txn.group_index, (
    "input must immediately precede the route"
)
```

A transfer elsewhere in the group is not the route's input, is never examined,
and executes on its own terms. The hygiene guard walks the whole group but
reads only `rekey_to`, `close_remainder_to`, `asset_close_to` and `fee` — never
an amount or a receiver.

**It is left open deliberately.** The rule that would close it — the caller may
only pay this application — refuses `sweep-6-convert` in [evidence/](evidence/),
where a leg pays a pool escrow directly. That is a route shape the router uses
on purpose, so neither this contract nor the browser can forbid the pattern
without forbidding the product. The finding records two partial mitigations and
is explicit that neither is a fix.

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

### 4.2 Five of these, checked against transactions rather than source

[evidence/](evidence/) holds seven groups that executed on mainnet on
2026-08-31 — the first time in this series that any claim has been checked
against a running system. What they settle:

| | what the trace shows |
|---|---|
| `H1` | four groups, four co-signed floors, all bound. Received cleared the floor by 0.50–0.97% |
| `M2` | fourteen route calls, each funded by the transaction immediately before it |
| `M4` | nine distinct pools called, every one pinned by template id or by a creator on the compiled whitelist |
| `M5` | two STAMM legs, **exactly eight** opups each, all to `STAMM_OPUP_APP_ID` |
| §2.3 | **183** inner transactions, every one at `fee: 0` |
| §2.4 | every holding the contract opened it closed in the same group |

Two further things the source did not say, and the trace did. The fee is taken
only on an ALGO hop, so **two route calls that moved real value paid the
platform nothing** — correct per `_skim`'s own docstring, invisible without
totalling the state deltas. And a group can mix router legs with a **direct
pool leg the co-signed floor does not cover**; nothing was lost, and it is a
boundary of the audited control surface rather than a finding. Both are in
[evidence/README.md §8 and §10](evidence/README.md).

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
- **No key-management review.** Admin key custody and signer rotation remain
  out of scope.

  **The deployment procedure no longer is.** It was excluded by all seven
  audits, and the exclusion had cost something measurable — an unnecessary
  mainnet redeploy, a conversion pool set wrong and corrected on chain, and a
  README step order that fails when followed — so it was the first thing
  [methodology/ultrareview.md](methodology/ultrareview.md) proposed spending a
  deeper review on. That review ran on 2026-09-01 and found **five ordering
  gaps**, every one of them a guard that existed as prose, as an optional flag,
  or aimed at a slightly different question than the one that mattered:

  | | |
  |---|---|
  | 1 | `verify_deployment` did not compare the manifest's application id against `router/deployments.py`, so a rollout that skipped step 3 configured the predecessor and verified the replacement — and every step reported success |
  | 2 | `retire.py` guarded the *network* but not the application id, which is the argument that gets mistyped; `blockers()` passes on a fresh replacement and refuses the predecessor, so it stopped the right target and let the wrong one through |
  | 3 | `DEPLOYER_RESERVE` was a flat 150,000 and ignored what the create itself costs — 635,500 for this schema — so a deployer funded to exactly what the check asked for cleared the create and fell short on the payment, leaving an application that exists and can route nothing |
  | 4 | the fee, quote signer and conversion pool were verified only when the operator passed the matching flag, which the README's step 7 did not |
  | 5 | the identical-redeploy check lived in the README's prose, where it was skipped once at the cost of a mainnet application |

  Fixed in `96da3d9`. The reserve formula in (3) was confirmed against the live
  mainnet deployer: 100,000 + 7×100,000 + 635,500 = 1,435,500, which is exactly
  what algod reports for that account.

  None of these is a contract finding and none has an `S`-number: they cannot
  move value on chain, and grading them beside `S2` or `S8` would misrepresent
  both. What they can do is produce a deployment that is wrong in a way nobody
  notices, which is how `3688554446` happened.
- **No live adversarial testing** against mainnet. The groups in
  [evidence/](evidence/) are a trace of successful operation. **They cannot
  show that a control fired**, only that nothing needed it to: no group there
  carries a rekey for the guard to catch or an over-budget opup request for
  `M5` to refuse. Every negative claim in this report still rests on source and
  on `simulate`.
- **The AlgoFi whitelist is a list**, and a list is a maintenance commitment.
  23 pool identifiers are compiled in; a pool that is not on it is unreachable,
  and one that should not be on it is reachable until a redeploy. No AlgoFi
  pool appears in the live evidence, so the list is unexercised there too.

---

## 6. Static analysis

Tealer 0.1.2, every detector, **4,768 TEAL lines**, revision `a6b9df6`, swept
2026-09-01. Detail in [tools/tealer.md](tools/tealer.md).

**The swept program is the deployed program**, which has not been true before
in this series. The sweep compiles with `RESTRICT_TO_ADMIN = 0` deliberately —
the unrestricted build is the superset — and until 2026-08-30 mainnet ran the
restricted one, so the two could only be compared by argument. They now hash
the same: `f568200e…c8aa4`, matching `approval_teal_sha256` in
`router-mainnet-3692588382.json`, with `verify_deployment.py` exiting 0 against
the deployed application. `verify.sh` checks that hash.

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

**Nothing moved against the previous sweep**, and that is the result rather
than an absence of one. `set_paused`, the group fee bound and the two setter
guards added 87 TEAL lines on the path every routed group takes; diffed
detector for detector against `75087b8`, nine of fourteen logs are byte
identical and the other five differ only in block numbering — 252 basic blocks
to 254, 52 dynamic group accesses to 53. **No detector changed its verdict or
its count.**

---

## 7. Reproducing this

```bash
git clone <this repository>
cd asastats-router-audit/verification

ROUTER=/path/to/router ./verify.sh   # 39 checks against the source
python3 verify-groups.py             # 62 more against what executed
```

Neither needs a node or credentials. `verify-groups.py` takes four further
checks — asset creators, application creators, whether the retired application
is gone, whether the live one carries `paused` — if `ALGOD_URL` is set, and
reports them `SKIP` rather than passing them silently if it is not.

If a claim in this report is not covered by one of those, treat it as
unverified and tell us. The dust sweep has a third script of its own; see
[SWEEP-REPORT §7](SWEEP-REPORT.md).
