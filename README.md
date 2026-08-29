# ASA Stats Smart Router — Security Audit

A security audit of the [ASA Stats](https://asastats.com) smart router: an
Algorand application that executes multi-hop swaps across Tinyman v2, Pact,
STAMM and AlgoFi inside a single atomic group.

**[Read the report →](REPORT.md)**  ·  **[What this is worth →](DISCLAIMER.md)**

---

## The short version

No critical or high-severity vulnerability was found in the contract. All 23
findings from the five previous audits are closed, and every mitigation was
re-derived from the source rather than taken on trust.

One real defect was found, in the off-chain sweep planner rather than the
contract: an unpriced holding could be given away to its creator with no test
of what it was worth. Live data showed an asset valued at 245.88 ALGO on the
user's own portfolio page sitting one checkbox from that path. It is
[fixed](findings/S1-unpriced-forfeit.md).

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
ROUTER=/path/to/router ./verify.sh
```

27 checks. No node, no credentials, no network. The recorded output is in
[verification/RESULTS.md](verification/RESULTS.md). If something in the report
is not covered there, it is not verified — and [REPORT.md §5](REPORT.md) says
what was deliberately left unchecked.

## Layout

| path | what is in it |
|---|---|
| [REPORT.md](REPORT.md) | the audit |
| [DISCLAIMER.md](DISCLAIMER.md) | how this was produced and what that costs |
| [findings/](findings/) | one file per finding |
| [verification/](verification/) | the script behind every claim, and its recorded output |
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
