# The five audits before this one

Preserved as issued, errors included. They are here because the pattern across
them is more instructive than any single finding, and because an audit series
that quietly deletes its mistakes teaches nobody anything.

**One change was made to these documents on import**, and only one: absolute
local paths were replaced with placeholders — `/home/<user>/…/router` became
`<router>`, and so on, across 11 files. No claim, number, verdict or finding
was altered. The word "preserved" is doing real work here, so the exception is
recorded rather than left for a reader to discover.

`v5` is the one exception: it was corrected in place on 2026-08-29 with a
`CORRECTIONS.md` enumerating every change and the retracted claims struck
through rather than removed. The uncorrected assertions are still legible next
to their retractions.

| | date | what it contributed | what it got wrong |
|---|---|---|---|
| [v1](v1/) | 2026-08-11 | Found `C1` (permissionless `convert_and_distribute` drained accrued fees) and `H1` (frontend-supplied `minimum_received = 0`). Both real, both critical to close. | — |
| [v2](v2/) | 2026-08-13 | Designed the co-signed floor that closed `H1`. Raised pre-held input conservation and funding adjacency. | — |
| [v3](v3/) | 2026-08-15 | Synthesised 134 attack vectors and the Trail of Bits scanner patterns into a formal plan. Capped STAMM opups. | — |
| [v4](v4/) | 2026-08-22 | Pact MWPT integration analysis; weight-asymmetry quoting. | **Recommended removing `RESTRICT_TO_ADMIN`** on the grounds that "mainnet has been running unrestricted for months". Mainnet was the restricted one. The application id it cited as evidence, `769636397`, was the **testnet** deployment. |
| [v5](v5/) | 2026-08-29 | On-chain MWPT vault verification; liquid staking pricing; first review of the dust sweep. | **Recorded the removal of `RESTRICT_TO_ADMIN` from mainnet `3688554446` as already delivered.** It never happened. On that basis its summary opened "secure for unrestricted mainnet production deployment". Also: "982 test cases" for a file collecting 111; the swept-TEAL digest labelled as the deployed bytecode hash; v4's mainnet and testnet baselines swapped; 24 findings claimed against 23; liquid staking pricing described backwards, contradicting its own finding `I1`; and finding `I2` marked "verified safe" without reading the predicate that decided it — which contained a real defect, now [`S1`](../findings/S1-unpriced-forfeit.md). |

## And what v6 got wrong

Kept here rather than in a corrections file, because the table above is only
honest if this repository is in it.

**v6 — the audit in the root of this repository — described a mainnet
deployment that had been replaced the same afternoon.** It was published on
2026-08-30 opening "the mainnet deployment is restricted to its admin, and this
audit does not clear it to be otherwise". `3689591968` went up hours later with
`RESTRICT_TO_ADMIN` off. The report was not wrong when written and was wrong by
the end of the day, which for a document whose subject is a live contract is
the same thing.

It is the **same class of error** as v4's and v5's, arrived at innocently: a
statement about a running system, sourced from a document rather than from the
system. The difference is only that v6's was stale rather than invented.

Corrected 2026-09-01. The durable fix is not the correction — it is
[evidence/](../evidence/) and `verify-groups.py`, which answer "what is
deployed" by reading transactions that executed. Every audit in this series
including this one has been able to read a contract. None before could tell you
what was running.

## The pattern

Four of the five contributed genuine security value. The contract is better
for all of them, and the findings they raised were real.

What failed, three times now, was **reporting a fact about a running system
that nobody had checked against one** — and twice in the same direction:
towards removing the one control standing between an unaudited contract and the
public.

That direction is not a coincidence. An audit that concludes "this is fine"
reads as a successful audit. The incentive inside a system asked to evaluate
something is to find that it evaluates well, and fluent text makes an unchecked
claim indistinguishable from a checked one.

None of the three required expertise to catch. `RESTRICT_TO_ADMIN` is a
template value in the deployment manifest and a property of any group that has
executed. The test count is `pytest --collect-only`. All were one command away.

Hence [verification/](../verification/): not because the checks are clever, but
because a claim that cannot be re-run is not a finding. `verify.sh` for the
source, `verify-sweep.sh` for the off-chain estate, and — after v6 made the
third version of this mistake — `verify-groups.py` for the chain.

## Reading these

The v1–v4 documents describe contract states that no longer exist. Findings
marked open in them may have been closed several revisions ago. For what is
true now, read [REPORT.md](../REPORT.md); for what was true then, read these
with their dates in mind.
