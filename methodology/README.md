# Method

## What was done

1. **Read the contract.** 2,391 lines of Algorand Python, all 14 entry points,
   the guards in each, and the helpers they call.
2. **Derived the access-control matrix mechanically** by parsing for decorated
   methods and the assertions inside each body, rather than reading it off.
   That is how the two entry points *without* the group-hygiene guard were
   found — a manual pass had recorded all 14 as guarded.
3. **Re-verified every prior finding against the source.** Not against the
   previous report. Where a mitigation was claimed, the code implementing it
   was located and quoted.
4. **Turned each claim into a command.** 27 checks in
   [verify.sh](../verification/verify.sh), output recorded.
5. **Re-proved the static-analysis verdicts** rather than inheriting them.
6. **Exercised the off-chain sweep against live data** — the only part of this
   audit that touched a running system — which is where the one real finding
   came from.

## What "verified" means here

That a command was run and its output recorded. Nothing in
[REPORT.md](../REPORT.md) says "verified" on the strength of reading a test
name or trusting a previous report.

That standard exists because of a specific failure. Audit v5 marked the dust
sweep's classification "VERIFIED SAFE", citing a test class as evidence —
a test class written in the same commit as the code it was certifying. The
predicate that actually decided the question was never read, and it contained
[a real defect](../findings/S1-unpriced-forfeit.md).

**A test asserting that something is safe is not evidence that it is.** It is
evidence that someone believed it was, which is the same thing the audit is
supposed to be checking.

## What an AI audit is good and bad at

Worth writing down, since this is the sixth and the pattern is now visible.

**Good at:** reading a large contract quickly and holding it in view at once;
noticing structural shapes (every entry point does X, these two do not);
mechanical derivation; cross-referencing a claim against source; generating the
adversarial cases for a given mechanism.

**Bad at:** knowing when it does not know. The output has the same fluency
whether the underlying claim was checked or invented. Every serious error in
this series is that failure — a test count invented, a deployment property
asserted backwards, a mainnet id confused with a testnet one — and none of them
required expertise to catch. They required someone to run one command.

**Systematically biased towards approval.** An audit concluding "this is fine"
reads as a successful audit. Two of five recommended removing the one control
standing between an unaudited contract and the public, both arguing from a
false premise, both in the same direction. That is not random error.

The mitigation is not more careful prose. It is making claims executable, so
that the difference between a checked claim and an invented one is a script
exiting non-zero.

## Scope

**In:** `contracts/router_app.py` and the off-chain planning code that decides
what a user is asked to sign — `router/sweep.py`, `router/selection.py`.

**Out:** the AMM contracts the router calls; key management and deployment
operations; the quoter's pricing quality; formal verification; economic and MEV
modelling; live adversarial testing. Listed with reasons in
[REPORT.md §5](../REPORT.md).

## Lineage

Built on the five prior audits ([history/](../history/)), the LiquiHog STAMM
AMM audit, three independent meta-analyses of it, and the Trail of Bits
Algorand vulnerability patterns. Where those raised a vector, it was checked
against this contract rather than assumed to transfer — the minimum-balance
drain is the clearest example: a real risk for the general shape, closed here
by `_routed_in_group`.
