# ASA Stats Smart Router — Security Audit

A security audit of the [ASA Stats](https://asastats.com) smart router: an
Algorand application that executes multi-hop swaps across Tinyman v2, Pact,
STAMM and AlgoFi inside a single atomic group.

**[Read the contract audit →](REPORT.md)**  ·
**[Read the dust sweep audit →](SWEEP-REPORT.md)**  ·
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

All three are fixed. The fee bound landed twice — in the widget for close-out
groups, and as a fourth assertion in the contract's own group-hygiene guard for
every routed group — and that second half is **source-only until the contract
is redeployed**.

Those fixes were then followed by 35 property tests, because every one of them
had been certified by example tests its own author wrote — the exact pattern
that produced the first finding. They turned up a fourth defect on their first
run, in both languages at once. See [SWEEP-REPORT.md](SWEEP-REPORT.md).

**The mainnet deployment is restricted to its admin, and this audit does not
clear it to be otherwise.** Every audit of this contract — this one included —
was produced by an AI system, and none has been reviewed by a human with
Algorand experience. Two prior audits recommended lifting that restriction and
both were arguing from a false statement of fact. See
[DISCLAIMER.md](DISCLAIMER.md).

## Check it yourself

Every factual claim in the report is a command:

```bash
cd verification
ROUTER=/path/to/router ./verify.sh          # the contract — 27 checks
ROUTER=/path/to/router ./verify-sweep.sh    # the dust sweep — 33 checks
```

`verify.sh` needs no node, no credentials and no network. `verify-sweep.sh`
needs node.js and, for two of its checks, a mainnet algod — it reports those
as `SKIP` rather than passing them silently when one is not configured. Neither
script submits anything; the chain cases use `simulate` with no key.

The recorded output is in [verification/RESULTS.md](verification/RESULTS.md)
and [verification/SWEEP-RESULTS.md](verification/SWEEP-RESULTS.md). If
something in either report is not covered there, it is not verified — and each
report's final sections say what was deliberately left unchecked.

## Layout

| path | what is in it |
|---|---|
| [REPORT.md](REPORT.md) | the contract audit |
| [SWEEP-REPORT.md](SWEEP-REPORT.md) | the dust sweep audit — off-chain, separate scope |
| [DISCLAIMER.md](DISCLAIMER.md) | how this was produced and what that costs |
| [findings/](findings/) | one file per finding |
| [verification/](verification/) | the scripts behind every claim, and their recorded output |
| [contracts/](contracts/) | access-control matrix and architecture notes |
| [tools/](tools/) | Tealer static analysis |
| [history/](history/) | audits v1–v5 as issued, and what each got wrong |
| [methodology/](methodology/) | scope, approach, and what an AI audit can and cannot do |

## The contract

| | |
|---|---|
| source | `router/contracts/router_app.py`, 2,391 lines of Algorand Python |
| compiled | 4,681 lines of TEAL v11, PuyaPy 5.9.0 |
| mainnet | [`3688554446`](https://allo.info/application/3688554446) — restricted to admin |
| testnet | `770123816` — unrestricted |
| audited revision | `8d130d6` |

## Why there are six of these

Because the first five were not reproducible, and three of them said things
that were not true. The full accounting is in [history/](history/); the short
version is that fluent prose asserting an unchecked fact is the characteristic
failure of an AI audit, and the only defence found so far is to make every
claim executable.

That is what this repository is for. Corrections welcome — especially from
people who have written Algorand contracts in anger.
