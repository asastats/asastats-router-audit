# ASA Stats Smart Router — Security Audit

A security audit of the [ASA Stats](https://asastats.com) smart router: an
Algorand application that executes multi-hop swaps across Tinyman v2, Pact,
STAMM and AlgoFi inside a single atomic group.

**[Read the contract audit →](REPORT.md)**  ·
**[Read the dust sweep audit →](SWEEP-REPORT.md)**  ·
**[What the contract actually did →](evidence/)**  ·
**[What this is worth →](DISCLAIMER.md)**

---

## The short version

**The contract.** No critical or high-severity vulnerability was found. All 23
findings from the five previous audits are closed, and every mitigation was
re-derived from the source rather than taken on trust.

One real defect was found in the off-chain sweep planner: an unpriced holding
could be given away to its creator with no test of what it was worth. Live data
showed an asset valued at 245.88 ALGO on the user's own portfolio page sitting
one checkbox from that path. It is [fixed](findings/S1-unpriced-forfeit.md).

**The dust sweep.** That last finding was reason enough to audit the sweep
properly, since it is the only feature in the product that gives a user's
assets away. Three further defects, all off-chain — the browser control that
inspects what a user is asked to sign took its reference for the most damaging
field from the same response it was checking; nothing anywhere bounded the fee,
and mainnet would accept a close-out group whose fees consume the account's
entire spendable balance; and the value veto added for `S1` guarded the path
needing an explicit tick rather than the path that needs none.

All three are fixed, and since 2026-08-30 both halves of the fee bound are
deployed rather than one. Those fixes were then followed by 35 property tests,
because every one of them had been certified by example tests its own author
wrote — the exact pattern that produced the first finding. They turned up a
fourth defect on their first run, in both languages at once. See
[SWEEP-REPORT.md](SWEEP-REPORT.md).

**The mainnet deployment is no longer restricted to its admin, and this audit
did not clear it to be otherwise.** `3692588382` went up on 2026-09-02 with
`RESTRICT_TO_ADMIN` off, and the seven mainnet groups in [evidence/](evidence/)
— routed by an account that is not the admin — are the proof rather than the
claim. The restriction had been doing two jobs at once: while it was set, the
admin was the only caller *and* the only stop button, because the contract had
none. What replaces it is `set_paused`, [pressed on mainnet before it was
trusted](contracts/going-unrestricted.md), and a group fee bound sized from the
dearest legitimate route. Neither depends on any of this analysis being
correct, which is the entire reason to prefer them to more analysis.

Every audit of this contract — this one included — was produced by an AI
system, and none has been reviewed by a human with Algorand experience. Two
prior audits recommended lifting that restriction and both were arguing from a
false statement of fact. **The restriction coming off does not retire that
warning; it is what makes it load-bearing.** See [DISCLAIMER.md](DISCLAIMER.md).

## Check it yourself

Every factual claim in the reports is a command. 186 of them:

```bash
cd verification
ROUTER=/path/to/router ./verify.sh              # the contract, from source — 39
ROUTER=/path/to/router ./verify-sweep.sh        # the dust sweep — 94
python3 verify-groups.py                        # what the chain did — 65
```

`verify.sh` needs no node, no credentials and no network. `verify-sweep.sh`
needs node.js and, for three of its checks, a mainnet algod — 81 without one.
`verify-groups.py` runs offline against the transactions in
[evidence/](evidence/) — 58 — and adds four more when a node is configured.

**All three count what they skipped, and say so on the last line.** That is not
decoration: `verify.sh` had no skip counter at all, so an absent deployment
manifest took its whole final section out of the run behind a cheerful
`passed 38, failed 0`. None of them submits anything; the chain cases use
`simulate` with no key.

Recorded output: [RESULTS.md](verification/RESULTS.md),
[SWEEP-RESULTS.md](verification/SWEEP-RESULTS.md),
[GROUP-RESULTS.md](verification/GROUP-RESULTS.md). If something in a report is
not covered there, it is not verified — and each report's final sections say
what was deliberately left unchecked.

## Layout

| path | what is in it |
|---|---|
| [REPORT.md](REPORT.md) | the contract audit |
| [SWEEP-REPORT.md](SWEEP-REPORT.md) | the dust sweep audit — off-chain, separate scope |
| [evidence/](evidence/) | seven groups that executed on mainnet, and what they settle |
| [DISCLAIMER.md](DISCLAIMER.md) | how this was produced and what that costs |
| [findings/](findings/) | one file per finding |
| [verification/](verification/) | the scripts behind every claim, and their recorded output |
| [contracts/](contracts/) | access-control matrix, architecture notes, and [what the admin restriction was doing before it came off](contracts/going-unrestricted.md) |
| [tools/](tools/) | Tealer static analysis |
| [history/](history/) | audits v1–v5 as issued, and what each got wrong |
| [methodology/](methodology/) | scope, approach, what an AI audit can and cannot do, and [how to spend a multi-agent review on it](methodology/ultrareview.md) |

## The contract

| | |
|---|---|
| source | `router/contracts/router_app.py`, 2,580 lines of Algorand Python |
| compiled | 4,892 lines of TEAL v11, PuyaPy 5.9.0 — `953988d9…1684`, [swept clean](tools/tealer.md) and matching the deployment manifest |
| mainnet | [`3692588382`](https://allo.info/application/3692588382) — **unrestricted**, 5 bps, deployed 2026-09-02 from `1e38529` |
| testnet | `770893297` — unrestricted, 0 bps, deployed 2026-09-02 |
| retired | mainnet `3689591968` and `3688554446`, testnet `770729651` and `770123816` — all four destroyed |
| audited revision | `8d130d6`, re-verified at `a6b9df6` and again at `1e38529`, the commit the live application was compiled from |

## Why there are six of these

Because the first five were not reproducible, and three of them said things
that were not true. The full accounting is in [history/](history/); the short
version is that fluent prose asserting an unchecked fact is the characteristic
failure of an AI audit, and the only defence found so far is to make every
claim executable.

**This one went stale within a day of being published**, which is worth saying
out loud: it opened by describing a mainnet deployment that was replaced the
same afternoon by an unrestricted one. That is the same class of error as v4's
and v5's — a statement about a running system, made from source — and the fix
is the same too. `verify-groups.py` and [evidence/](evidence/) exist so that
the next reader finds out from a command rather than from a paragraph.

That is what this repository is for. Corrections welcome — especially from
people who have written Algorand contracts in anger.
