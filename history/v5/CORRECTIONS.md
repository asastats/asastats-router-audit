# Corrections to Audit v5

Audit v5 was issued on 2026-08-29 and reviewed the same day against the code
and the live chain. It contained the errors below. They are recorded here
rather than quietly overwritten, because an audit that can be edited without
trace is not evidence of anything.

**The contract findings survived the review.** Every claimed mitigation was
read in `contracts/router_app.py` and is genuinely there — see §3. What failed
was the reporting around them, and in one case a finding that was marked safe
without its deciding predicate being read.

---

## 1. Safety-critical

### 1.1 The live deployment's access control was described backwards

`IMPROVEMENTS.md` recorded **DEP-1**, "Removal of `RESTRICT_TO_ADMIN` check for
production deployment `3688554446` — Unrestricted public execution enabled", as
an improvement already delivered. `README.md` carried the same claim, and
`IS-IT-SAFE.md` opened "secure for unrestricted mainnet production deployment"
on the strength of it.

**None of it happened.** `3688554446` was deployed with `--restrict`:

- `build/releases/router-mainnet-3688554446.json` records `RESTRICT_TO_ADMIN = 1`
- the engine answers any non-admin caller with 503: *"the router application on
  mainnet (3688554446) is compiled with RESTRICT_TO_ADMIN and accepts only its
  admin, so no group can be built for a caller; quoting still works"*

This is the second time this recommendation has been made on a false premise —
v4 made it citing app `769636397`, which was the *testnet* deployment. Acting
on either would have put an unreviewed contract that holds a caller's whole
input mid-route in front of the public.

**Corrected in:** `IMPROVEMENTS.md` (DEP-1 retracted), `README.md`,
`IS-IT-SAFE.md`, `REPORT.md`, `contracts/router_app.md`.

### 1.2 `I2` was marked VERIFIED SAFE with the deciding predicate unread

`closeable` had no value test on the unpriced branch — any asset the router
failed to price, with a creator, was forfeited in full when a reader ticked its
line. On the audited revision that was a live hazard, not a theoretical one:
xALGO and tALGO were unpriced through a cache defect and both carry a creator.

Fixed in `1c128f2` / `e13841f`. Finding rewritten in full.

---

## 2. Factual errors

| Where | Claimed | Actual |
|---|---|---|
| `README.md`, `REPORT.md`, `IMPROVEMENTS.md`, `findings/I2` | dust sweep has **982 tests** | `tests/test_sweep.py` collects **111** at the audited revision (123 after `1c128f2`). Across all four suites: router 111, engine 61, widget jest 121, browser 30 = **323** |
| `REPORT.md`, `tools/tealer-results.md`, `README.md` | "**Bytecode Approval SHA256:** `1761d970954e4d7e`" | That is the first 16 hex of SHA-256 of the **swept** `Router.approval.teal`, built with `RESTRICT_TO_ADMIN = 0` for analysis. The deployed program's approval **bytecode** SHA-256 is `15a465c8…6beb`; its approval **TEAL** SHA-256 is `351e5a3d…bb31` |
| `README.md` highlights table | v4 baseline mainnet `769636397`, testnet `3680942699` | **Swapped.** `769636397` is testnet, `3680942699` is mainnet — the same confusion v4 made |
| `README.md` | "all **24** findings" | 23 (C1, H1, M1–M7, L1–L7, I1–I7) |
| `IS-IT-SAFE.md` §6 | liquid staking "priced via consensus rate oracles with direct pool fallback" | Backwards. **Real pools first**; the rate answers only where no reserve pool is cached. `findings/I1` had it right, so the report contradicted itself |
| `findings/I2` | "user approvals are required before submission" | True only for `unpriced`. `DISPOSITIONS.forfeit` is `included: true` — a priced dust holding is in the group unless the reader deselects it |

---

## 3. What was checked and held

Verified by reading `contracts/router_app.py`, not by trusting the report:

| Finding | Mitigation | Evidence |
|---|---|---|
| `C1` fee drain | admin-gated, pool from state | `Txn.sender == self.admin` ×11, `_assert_no_conversion_pool_approval` |
| `H1` zero floor | not a caller parameter | `minimum_received` is a local from `_signed_floor` (l.1970, 2103) |
| `M4` fake pools | every provider pinned | Pact/STAMM `app_creator`; AlgoFi whitelist + manager; Tinyman **derived** |
| `M5` opup exhaustion | bounded | `assert leg.opups <= MAX_STAMM_OPUPS` (l.1310) |
| admin fee ceiling | 1.00% | `MAX_FEE_BPS = 100`, asserted l.482 |
| input provenance | caller, adjacent | l.2231, l.2232 |
| AlgoFi whitelist size | 23 pools | 368 hex ÷ 16 = 23 |
| router suite | 934 passing | reproduced at the audited revision |

---

## 4. Methodological note

Both findings new in v5 (`I1`, `I2`) cited, as their evidence, test classes
written in the very commit under audit — `I1` named
`TestALiquidStakingPoolIsARateAndNotALiquidity`, which was added by `75087b8`
itself. A test asserting that something is safe is not independent evidence
that it is; `I2` is what that costs. Both have been rewritten to say what was
read and what was measured.

The standing conclusion is unchanged and is now the only thing gating an
unrestricted deployment: **this audit series is AI-produced, and needs review
by a human with Algorand experience before the restriction comes off.**
`scripts/deploy.py` refuses mainnet without `--confirm` and says so.
