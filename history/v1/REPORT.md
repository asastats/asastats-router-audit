# Smart Router Security Audit Report

**Auditor:** AI-assisted audit (OpenCode), building on the STAMM AI audit and three independent analyses.  
**Date:** 2026-08-11  
**Contract:** `Router` in `router/contracts/router_app.py`  
**Network:** Algorand Mainnet (restricted deployment)  
**Scope:** On-chain router application and its off-chain group builder.

---

## Executive Summary

The smart router is a carefully engineered Algorand application that solves the core problem of executing a multi-hop route where the second hop's input depends on the first hop's realised output. The contract already implements several strong defences: derived Tinyman v2 pool addresses, balance-delta measurement of leg output, zero-fee inner transactions, a rekey/close group-hygiene check, and an opt-in handshake that protects the float.

The preliminary audit identified **one critical and one high-severity issue** that must be resolved before the contract is deployed unrestricted:

1. **Critical:** `convert_and_distribute` is permissionless and accepts a caller-supplied pool leg, allowing an attacker to drain accrued platform fees to a malicious pool. This has been patched in the source.
2. **High:** The residual risk from T5 — a compromised widget can pass `minimum_received = 0` and execute a trade through genuine pools at any price — is still open. The recommended fix is a backend-signed floor, analogous to the existing voucher mechanism.

No issue was found that allows theft of a caller's trade under the current restricted deployment, provided the admin key remains uncompromised.

## 1. Architecture

The router splits a swap across venues. Direct venues are assembled and signed off-chain. Routes (two- or three-hop paths) are executed by the `Router` application because the second/third hop's input is not known at signing time.

Key components:

- `route` / `route3`: receive the caller's input, swap through one or two pools, and pay the caller.
- `_swap_leg`: sends a fixed-input swap to Tinyman v2, Pact, STAMM, or AlgoFi.
- `_skim`: takes the platform fee from an ALGO-denominated leg.
- `verify_discount` / `_discount`: validates a backend-signed fee discount.
- `convert_and_distribute`: swaps accrued ALGO into ASASTATS for the platform escrow.

The contract holds no inventory between routes; it opens and closes opt-ins inside the same group.

## 2. Findings Summary

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| C1 | Critical | Permissionless `convert_and_distribute` with caller-supplied pool drains accrued fees | **Patched** |
| H1 | High | `minimum_received` is widget-controlled; a compromised frontend can pass zero | **Patched** |
| M1 | Medium | Route paths are not sanitised (cycles / duplicate assets) | **Patched** |
| M2 | Medium | No quote deadline / stale-group execution | **Patched** (structurally; see below) |
| M3 | Medium | Pact / STAMM / AlgoFi pool app IDs are not authenticated | **Patched** (creator pins; a list for AlgoFi) |
| M4 | Medium | Fee conversion pool is not pinned or approved | **Patched** (approved ahead of time; the argument is gone) |
| M5 | Medium | `opups` field is honoured for non-STAMM providers, wasting budget | **Patched** |
| M6 | Medium | Tinyman v2 validator app ID is a template variable; an upgrade breaks the contract | Accepted/Documented |
| L1 | Low | `delete_application` does not explicitly check for held ASAs | **Patched** |
| L2 | Low | `set_admin` / `set_escrow` do not reject the zero address | **Patched** |
| L3 | Low | No explicit reentrancy-style phase guard | Accepted/Documented |
| L4 | Low | `convert_and_distribute` does not enforce `minimum_out > 0` | **Patched** |
| L5 | Low | Voucher key compromise is bounded to revenue, but no rotation timelock | Documented |
| I1–I6 | Info | Various code-quality and documentation notes | Documented |

## 3. Critical Finding

### C1 — Permissionless fee conversion drains accrued fees

**Location:** `convert_and_distribute`  
**Impact:** Any accrued platform fees can be swapped into an attacker-controlled pool and lost.  
**Fix:** Make the method admin-only (or restrict conversion to approved pools). Implemented as admin-only.

The method is permissionless by design so that fees do not stall if the keeper is offline. However, it accepts a `Leg` argument that names the pool to convert through. A caller can pass a Pact (or STAMM/AlgoFi) app ID they control. The router deposits ALGO into that application's escrow and calls it; if the app returns no ASASTATS and the caller sets `minimum_out = 0`, the group succeeds, `accrued` is reduced, and the ALGO is gone.

The batch ceiling (`MAX_CONVERSION_BATCH`) only bounds how much is taken per call; the attacker can repeat the call until `accrued` is zero.

**Mitigation applied:** added `assert Txn.sender == self.admin` to `convert_and_distribute`.

## 4. High Finding

### H1 — Widget-controlled floor leaves users exposed

**Location:** `route` / `route3` `minimum_received` parameter  
**Impact:** A compromised frontend can set `minimum_received = 0` and execute a trade at any price through genuine pools. The loss is bounded by real pool depth rather than an attacker's own pool, but it is not zero.  
**Fix as recommended:** a backend-signed floor mirroring the voucher design — a `verify_quote` method checking an `ed25519verify_bare` signature, with `route` asserting the call is present.

**Fix as implemented, and why it differs.** The recommended shape costs three transactions per group: `ed25519verify_bare` is 1,900 opcode units against the 700 an application call is given, so it needs two `pool_budget` calls to afford one verification. Measured against the last full benchmark run, spending those three slots cost a mean of 2.4 basis points of realised output and up to 0.82% on the widest rows, because the allocator drops venues to make room.

Implemented instead as a **co-signed transaction**: the floor travels in the note of a transaction sent by a `quote_signer` account, so the AVM authenticates the sender and no signature is verified on-chain at all. One transaction rather than three, and no opcode budget spent on cryptography. `minimum_received` was removed from `route`/`route3` entirely rather than kept and cross-checked, so a caller cannot express a floor.

The note binds the application, the caller, the output asset, and each route call's input amount at that call's own group index — every field checked against something the contract already knows. It names the index of the call that asserts the floor, so a signed group cannot be trimmed of the only call that sees the group's whole output. `set_quote_signer` refuses the zero address: the signer may be rotated but never revoked, because a floor must fail closed and a fallback to a caller-supplied floor would reopen this finding to anyone holding the admin key.

Verified on LocalNet by `TestTheAuthorisedFloor` — foreign account, foreign application, wrong output asset, wrong input amount, wrong position, trimmed split, missing authorisation, misplaced authorisation, and rotation permissions.

## 5. Medium Findings

### M1 — Route path sanitisation

**Location:** `route` / `route3`  
**Impact:** A route like A → B → A wastes fees and can be used to confuse accounting or grief the caller.  
**Fix:** Added on-chain checks that `asset_in`, the intermediate(s), and `asset_out` are pairwise distinct.

### M2 — No quote deadline

**Location:** `route` / `route3`  
**Impact:** A quoted group can be submitted long after it was built. The slippage floor protects against price movement, but it does not protect against stale state or a user changing their mind.  
**Fix as recommended:** add a `deadline_round` parameter to `route`/`route3` and assert `Global.round <= deadline_round`.

**Resolved structurally instead, with no parameter.** The H1 fix makes a co-signed transaction mandatory in every routed group, and that transaction carries its own `lastValid` round. A group is atomic, so it cannot commit after its authorisation expires — the network enforces the deadline, and the contract needs no argument and no `Global.round` comparison. The quote's lifetime becomes a property the backend sets when it signs, which is where quote validity is decided anyway.

An auditor should check the consequence rather than assume it: this makes quoting mandatory before executing, since a group cannot be built from an authorisation that has expired.

### M3 — Unauthenticated pool app IDs

**Location:** `_pact_leg`, `_stamm_leg`, `_algofi_leg`  
**Impact:** The contract calls whichever app ID the caller passes. Atomicity and the output floor mean user funds are not stolen directly, but a malicious app ID can be used to grief (e.g., exhaust opcode budget) or, combined with a zero floor, to extract value. The zero-floor half closed with H1; what remained was an unbounded call surface — a confused deputy that would call anything from the router's own address — and the fact that it becomes every caller's to aim once `RESTRICT_TO_ADMIN` comes off.  
**Fix as recommended:** an admin-controlled whitelist of approved pool app IDs, or verification against official factory/registry contracts.

**Fix as implemented, and why it is not a whitelist.** A list of pool identifiers has to be maintained and is wrong the day a provider adds a pair — which Pact and STAMM do constantly. Their pools are instead pinned by **creator**: `AppParamsGet.app_creator` against a compile-time set of addresses. About five opcodes, no state, no boxes, and no extra resource reference, since the pool application is already available because the contract is about to call it.

Chosen on a full mainnet scan (2026-08-12): 3,189 of Pact's 3,218 pools come from one address and 21 more from its predecessor; **all 311** of STAMM's come from a single address. Program-hash pinning was rejected — Pact's current deployer ships at least three distinct approval programs, so it would take a set of hashes breaking on every upgrade, and hashing a two-kilobyte program costs more than a route has to spend.

A third Pact creator is deliberately excluded: it is the new pool factory, whose eight pools carry different state entirely (`asset_a` / `reserve_a` / `weight_a` against the older `A` / `B` / `CONFIG`). `pactsdk` cannot read them and `_pact_leg` sends a call they do not implement, so they are refused at our own boundary rather than failing inside Pact's.

**AlgoFi is the exception, and is a list.** Its pools were deployed permissionlessly — a sample of sixteen had twelve creators — so there is nothing to pin. Identifiers are listed and `leg.hub`, the manager application that was its second caller-supplied identifier, is pinned to the one they share. The list is a *liquidity curation* rather than the full set: the graph builds 470 AlgoFi pools, a 470-entry list is not affordable in either program size or opcodes, so it holds the 23 with at least 100 ALGO and legs through the rest are refused rather than traded. Acceptable only because AlgoFi shut down, so neither the set nor its liquidity moves.

Verified on LocalNet by `TestThePoolPins`, which deploys a second stub pool from a different account, stocked identically, so the only thing wrong with it is who created it.

### M4 — Fee conversion pool not pinned

**Not resolved by the C1 patch, contrary to what this report first said.** C1
made the method admin-only, which stopped a *stranger* naming the pool. It left
the *admin* naming it inside the same transaction that spends the money, so a
typo, a stale identifier or a pool since drained of liquidity converted the
treasury's ALGO at whatever price was there, in a call nobody could review
beforehand.

**Fix as implemented.** The argument was removed rather than cross-checked, the
same shape as H1's removal of `minimum_received`: `set_conversion_pool`
approves a leg ahead of time, in a transaction that spends nothing, and
`convert_and_distribute(batch, minimum_out)` reads it from state. All seven
`Leg` fields are pinned, because a pool is not one identifier — Pact and STAMM
are named by `app`, Tinyman by the pair its address is derived from, STAMM
further by `tier` and `hub`. Unset is an empty value rather than a zeroed
struct, since an all-zero `Leg` would silently name the Tinyman ALGO/ASASTATS
pool.

**What it does not do.** It is not a defence against a stolen admin key: that
key can call `set_escrow` and convert to itself perfectly legitimately, so the
accrued balance is reachable by it whatever is pinned. This guards mistakes,
which is the failure an admin-only method actually meets. The report should not
be read as claiming more.

**Cost.** It fails closed, so a deployment that never approves a pool cannot
convert — and since `delete_application` refuses while `accrued` is non-zero,
the first fee it skims makes it unretirable until the step is run. The float is
recoverable; `scripts/retire.py` reports the condition rather than leaving it
to a rejected transaction.

### M5 — `opups` field for non-STAMM providers

**Location:** `_swap_leg`  
**Impact:** A caller can set `opups > 0` on a Tinyman/Pact/AlgoFi leg, causing the contract to call the STAMM budget application and pay for no-ops that do not benefit that leg.  
**Fix:** Added an assertion that `opups == 0` unless the provider is STAMM.

### M6 — Tinyman validator upgrade risk

**Location:** `_tinyman_v2_pool`  
**Impact:** Tinyman's validator app ID is a compile-time template variable. If Tinyman upgrades its validator, all derived pool addresses change and the contract can no longer route through Tinyman v2.  **Fix/Status:** This is inherent to the design and acceptable if deployments are version-pinned. Document as a deployment risk.

## 6. Low & Informational Findings

See the individual files in `findings/` for full details. Notable items:

- **L1, patched.** `delete_application` now asserts `total_assets == 0`. The condition is an opt-in, not a balance — an account cannot close while opted into anything, funded or not. Worth recording that the method's *own docstring already claimed this check*: the finding was a documented guarantee the code did not provide, not a safeguard nobody had considered. `scripts/retire.py` had the same gap one level up, filtering holdings on `amount > 0`, and would have reported no blockers while the delete failed anyway.
- `set_admin` and `set_escrow` should reject the zero address. **Patched (L2).**
- A reentrancy-style phase guard is not required on Algorand because the AVM rejects callbacks to an app already on the call stack, but it may be worth adding for defence-in-depth if the contract is later composed with untrusted apps.
- **L4, patched.** `convert_and_distribute` requires `minimum_out > 0`, placed after the batch bounds so their more specific messages still fire first. As with M4, this addresses an admin *mistake* and not a compromised admin key; the original finding claimed both.

## 7. Recommendations

1. ~~**Do not remove `RESTRICT_TO_ADMIN` until H1 (signed floor) is implemented and M2 (deadline) is added.**~~ Both are now implemented. The restriction should still not be lifted until this audit is reviewed by an Algorand-experienced human auditor and M3 is addressed.
2. **Keep `convert_and_distribute` admin-only** (or implement an approved-pool whitelist if permissionless operation is essential).
3. ~~**Implement the signed-floor mechanism** as the highest-priority improvement.~~ Done, as a co-signed transaction rather than an on-chain signature check — see H1 for why the shape differs and what it costs.
4. ~~**Add a deadline parameter** to the next deployment's `route`/`route3` methods.~~ Not needed: the authorisation's own `lastValid` round is the deadline, enforced by the network. See M2.
5. ~~**Add an approved-pool whitelist** for Pact/STAMM/AlgoFi app IDs.~~ Done on both paths. The conversion pool is approved ahead of time (M4); routing pools are pinned by creator, with a fixed list for AlgoFi alone (M3). Neither is a maintained whitelist, which is the part of the recommendation that was not followed and the reason to read M3 rather than this line.
6. **Write semi-formal multi-hop invariants** and, budget permitting, engage Runtime Verification for KAVM modelling.
7. **Expand the test suite** with malicious-pool harnesses, Hypothesis fuzzing, and differential tests against existing routers.
8. **Run a bug bounty** and continuous monitoring program after unrestricted deployment.

## 8. Conclusion

The smart router is a strong piece of engineering with a clear threat model and good defensive patterns. The critical permissionless-conversion issue has been patched, and the route-sanitisation / opups assertions close minor attack surfaces.

**Since this report was first written, H1 and M2 have both been resolved** in the same ABI change: `minimum_received` is gone from `route`/`route3`, the floor arrives co-signed by a `quote_signer` account, and that transaction's own validity window supplies the deadline.

**M4, L1 and L4 have since been resolved as well**, all three on the treasury path. M4's original status here — "patched via the C1 fix" — was wrong: C1 stopped a stranger naming the conversion pool and left the admin naming it at the point of spending. It is now approved ahead of time and the argument is gone. Two of the three findings claimed protection against a compromised admin key that no guard on this path can give, and the finding files now say so: an admin key reaches the accrued balance through `set_escrow` whatever is pinned.

**M3 has since been resolved as well.** Routing pools are authenticated by creator rather than by a maintained whitelist — one address covers every pool Pact or STAMM will ever deploy, which a list cannot — with AlgoFi listed explicitly because its pools were deployed permissionlessly and the protocol is shut down, so the list cannot go stale.

**Every finding this audit raised is now either patched or explicitly accepted.** What remains before the admin restriction can be lifted is not a finding: this audit is AI-assisted and has not been reviewed by an Algorand-experienced human, the changes have run on LocalNet and in simulation but not on mainnet, and no deployment yet carries M3, M4, L1 or L4.

The contract should nonetheless remain restricted to the admin, and no real user funds should be routed through it, until this audit is reviewed by an Algorand-experienced human auditor and the deployment carrying these changes has been exercised against real pools. The changes are verified on LocalNet and by simulation; they have not yet run on mainnet.
