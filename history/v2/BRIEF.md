# Brief for the second audit of the router

**Prepared:** 2026-08-12
**Subject:** `router/contracts/router_app.py` at `932ebfb`
**Analysed program:** `Router.approval.teal`, 4,444 lines, sha256 `e5015556d51489f5…`
**Question being asked:** may `RESTRICT_TO_ADMIN` be lifted?

This is a hand-off, not an audit. It says what changed since v1, what evidence
exists for each claim, and what is **not** covered — so a reviewer can spend
their time on the parts nobody has checked rather than rediscovering the parts
that are pinned.

---

## Read this first: what this deployment is

`3671595889` on mainnet, **restricted**: `route` and `route3` refuse every
caller but the admin. It holds a 20 ALGO float and charges 10 bps.

**It has now executed once on mainnet.** On 2026-08-12 the admin submitted a
real route — 0.20 USDC to HOG through Tinyman v2 and STAMM, txid
`YPFCLPLUZOXZMOWJFKTZCU5IV2CRUJVIX5CX3AZPCDLW42NRNFCA`, confirmed in round
64005042. It received 920,350 HOG against a floor of 902,845 and skimmed
2,522 microALGO, which is 10 bps of the 2.522 ALGO intermediate, exact to the
unit. The fee it skimmed was then converted, round 64005143: 2,522 microALGO into
15,457,090 ASASTATS through Pact 2757667443, taking `accrued` to zero. That
conversion went through the **final-sweep** branch — `batch == accrued`, below
`MIN_CONVERSION_BATCH` — which is the newest code in the contract and had only
ever run on testnet, where the dust was worth nothing and it received zero.
Here it received a real number, and the application closed the ASASTATS opt-in
it had borrowed within the same group.

Those two groups are the only real executions: everything else on mainnet in
this repository is a `simulate` call.

Testnet `769118401` is unrestricted and does execute for real.

The build submitted for analysis is compiled with `RESTRICT_TO_ADMIN = 0`
**deliberately**, because that is the superset and the thing being asked about.
It is not the bytecode currently deployed. See "What was analysed, and what is
deployed" in `router/docs/tealer-triage.md`, which pins the deployed build
separately by hash.

---

## The single most important thing in this document

**Every audit of this contract so far has been produced with AI assistance,
including the one that found C1 and H1, and including this brief.** No
Algorand-experienced human has reviewed the contract or the audits.

A second AI audit does not change that, and should not be mistaken for it. If
the goal of this round is to justify lifting the restriction, the reviewer this
needs is a human one. Everything below is intended to make that review cheap,
not to substitute for it.

---

## What changed since v1

v1 raised 1 critical, 1 high, 6 medium, 5 low. All are now patched or
explicitly accepted; `audit/router-audit-v1/REPORT.md` carries the table and
each `findings/` file records how the fix differs from the recommendation.

Four are worth a reviewer's attention because the **implementation deliberately
differs from what v1 recommended**:

| | Recommended | Implemented | Why |
|---|---|---|---|
| **H1** | `verify_quote` checking `ed25519verify_bare` | floor travels in the note of a transaction sent by a `quote_signer` account | 1,900 opcode units against the 700 an app call gets means two extra `pool_budget` calls; measured over 98 rows that cost a mean 2.4 bps of output and up to 0.82% on wide splits. The AVM authenticates a sender for free. |
| **M2** | a `deadline_round` argument | nothing — the authorisation's own `lastValid` | a group is atomic, so it cannot commit after its authorisation expires. The network enforces it. **Consequence a reviewer should check rather than assume: quoting is now mandatory before executing.** |
| **M3** | a whitelist of approved pool app ids | Pact and STAMM pinned by pool **creator**; AlgoFi a curated list | one creator covers every pool a provider will ever deploy; a list is wrong the day they add a pair. Measured: 3,189/3,218 Pact pools from one address, **311/311** STAMM from one. |
| **M4** | pin the conversion pool | removed the argument entirely; the pool is approved ahead of time | a parameter that must equal state is a parameter that can be got wrong. Same shape as H1's removal of `minimum_received`. |

### Where the fixes are weaker than they look

Stated here because the v1 finding files originally claimed more, and were
corrected:

- **M4 and L4 do not defend against a stolen admin key.** That key can point
  `set_escrow` at itself and convert perfectly legitimately. They guard
  *mistakes* — a typo, a stale pool id, one since drained of liquidity. No guard
  on the treasury path pretends otherwise; see the trust-boundary table in
  `router/SECURITY.md`.
- **M3's AlgoFi list is a liquidity curation, not the full set.** The graph
  builds 470 AlgoFi pools; the list holds the 23 with at least 100 ALGO. **A leg
  through any other AlgoFi pool is refused, not traded.** A 470-entry list is
  affordable in neither program size nor opcodes.
- **M3's pins are compile-time.** If Pact rotates its deployer, the constant is
  stale until the next deployment. The failure is loud — every Pact route
  refused — not silent. Same class as M6.

---

## Evidence, and how far each piece reaches

| Layer | What it proves | Count |
|---|---|---|
| `tests/test_router_contract.py` | guards, **by assertion message**, with state set directly | 50 |
| `tests/test_contract_localnet.py` | behaviour against a real ledger, inner transactions, borrowed opt-ins | 93 |
| `tests/test_contract_testnet.py` | real routes **submitted and confirmed** against Tinyman and Pact | 11 (1 skipped) |
| `tests/test_execute.py` | groups simulated against live mainnet pools, `allow_unnamed_resources=False` | 19 |
| whole suite | | **662 passed, 2 skipped** |

Four benchmark sweeps ran against `3671595889` on 2026-08-12 — 784 rows of real
quoting and group building — with **zero groups refused by the contract**. The
8 refusals `trend.py` attributes to our own contract are all on retired
applications.

**Static analysis:** `router/docs/tealer-triage.md`, regenerated for this build.
Three detectors cannot finish their path walk and are replaced by *covered*
reports that prove the verdict directly rather than recording an absence
(`scripts/tealer_covered.py`). `is-deletable` genuinely fires and is meant to:
`delete_application` is admin-only, guarded, and exists so a superseded
deployment's float is recoverable.

**Invariants:** `router/docs/invariants.md` — 25 properties, each naming the
assert that enforces it and the test that fails if the enforcement is removed.
This is v1's recommendation 6. It is a checkable list and a gap report, not a
proof; recommendation 6's other half, KAVM modelling by Runtime Verification,
has not been done.

---

## What a reviewer should attack first

Ranked by where the evidence is thinnest, not by where the code is newest.

1. **`_signed_floor` and the note layout.** The whole slippage protection of
   every user rests on it, and it is the newest substantial code. The note binds
   application, caller, output asset, per-index input amount and the asserting
   call's index. Is that binding complete? Specifically: can a group be
   assembled that satisfies every field and still pays the caller less than the
   floor the backend intended?
2. **`route3`.** Its five sanitisation asserts have **no direct test** —
   nothing drives `route3` on LocalNet. This is the one acknowledged gap in
   `invariants.md` worth closing, and it is the three-hop path, which is the
   most complex thing the contract does.
3. **The measurement window (invariants B1–B3).** Nothing may spend from the
   application account between the two balance readings that measure a leg. This
   is enforced by *construction* — `fee=0` on every inner transaction — not by
   an assert. A reviewer who finds a path that spends inside that window has
   found a real bug.
4. **Opcode budget under an unrestricted caller.** `stamm_opups` is a caller
   field; the budget pools across a group at 700 per app call. An adversarial
   caller choosing pathological combinations is not something the benchmark
   explores.
5. **The AlgoFi 23-entry scan** — the only unbounded-ish loop in the contract,
   and its opcode cost is reasoned rather than measured, because no AlgoFi leg
   has run against this deployment.

---

## Open items, and who can close them

**Nothing in this repository can close the first one.**

| Item | Status | Who |
|---|---|---|
| Human expert review of contract and audits | not started | external |
| Bug bounty | not started | operator; only meaningful once unrestricted |
| Continuous monitoring | not started | operator — see below |
| Fee conversion end-to-end through a real pool | **done on testnet** 2026-08-12, through a live Pact pool, with the contract reading the pool from state. Not yet on mainnet | — |
| One real mainnet route, submitted | **done** 2026-08-12, round 64005042 — floor honoured, fee exact | — |
| Fee conversion on **mainnet** | **done** 2026-08-12, round 64005143 — and it exercised the *final-sweep* branch specifically | — |
| `route3` sanitisation tests | gap recorded in `invariants.md` | engineering |
| KAVM modelling | not started | external, paid |

### Monitoring, concretely

The plumbing exists — an hourly sweep and a 15-minute AMM rsync, both currently
uninstalled from cron. What is missing is safety signal rather than competitive
measurement:

- **any** admin method firing (`set_admin`, `set_escrow`, `set_fee`,
  `set_quote_signer`, `set_conversion_pool`). They are rare by design, so an
  unexpected one is the highest-signal alert available.
- `accrued` moving with no route behind it, or by more than the rate allows
- the float dropping without a matching opt-in cycle
- **Pact or STAMM leg counts falling to zero** — this is what M3's pins going
  stale looks like from outside, and it is a live risk: Pact is mid-migration to
  a new pool generation this contract cannot trade through.

### One coverage risk that is not a finding

`router.venues.pact_venues` catches the read failure on Pact's new-generation
pools and returns `[]`. They are skipped **silently**. As Pact migrates
liquidity, the router will quietly stop seeing it, and the symptom is a slow
decline in benchmark results with no error anywhere. Not a contract flaw;
worth an alert.

---

## Recommendation

The engineering is ready for review. **It is not ready for the restriction to
be lifted**, and the gap is not code — it is that no human with Algorand
experience has read any of this, the contract has never executed on mainnet,
and the treasury path has never converted a fee outside LocalNet.

All three cheap items are done. The testnet conversion ran end to end through a
real Pact pool; one real mainnet route was submitted and confirmed; and the fee
it skimmed was converted on mainnet through the *final-sweep* branch, the
newest code in the contract and the one that had only ever run on testnet where
it received nothing. What is left is the admin-method alert — and the human
review, which is the long pole and should start now.
The human review is the long pole and should start now, in parallel.
