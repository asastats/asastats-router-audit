# Method

## What was done

1. **Read the contract.** 2,391 lines of Algorand Python, all 15 entry points,
   the guards in each, and the helpers they call.
2. **Derived the access-control matrix mechanically** by parsing for decorated
   methods and the assertions inside each body, rather than reading it off.
   That is how the two entry points *without* the group-hygiene guard were
   found — a manual pass had recorded all 15 as guarded, where 13 are.
3. **Re-verified every prior finding against the source.** Not against the
   previous report. Where a mitigation was claimed, the code implementing it
   was located and quoted.
4. **Turned each claim into a command.** 195 checks across
   [verify.sh](../verification/verify.sh),
   [verify-sweep.sh](../verification/verify-sweep.sh) and
   [verify-groups.py](../verification/verify-groups.py), output recorded.
5. **Re-proved the static-analysis verdicts** rather than inheriting them.
6. **Exercised the off-chain sweep against live data**, which is where the one
   real finding came from.
7. **Read seven groups that executed on mainnet** — added after this audit made
   the third stale-deployment error in the series. See
   [evidence/](../evidence/) and §"What source cannot answer" below.

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

## The limit of reading, and what got past it

Everything above is about *claims*. There is a second failure that executable
claims do not touch, and the dust sweep audit ran into it: an examiner reading
code finds the cases it occurs to them to look for, and so does an examiner
writing tests. Both are bounded by the same imagination.

`S1` is the clean example. Its example tests were thorough — five parametrised
cases for a payload that could not be read — and every one of them stayed
inside the type the author had in mind. Nobody wrote the case where the payload
is not a dict at all, because nobody thought of it, and that is exactly the
case [`S5`](../findings/S5-malformed-evaluation-raises.md) turned out to be.

**Property tests do not have that failure mode, because nobody chooses the
inputs.** 35 of them were added to the sweep after `S2`–`S4` were fixed —
hypothesis on the planner, fast-check on the browser control — each stating a
refusal rather than an example. They found `S5` on their first run, in both
languages at once.

That is also why they were added at all. Every fix in that audit was certified
by example tests its own author wrote in the same commit, which is precisely
the pattern that produced `S1` in the first place. Passing tests are evidence
the author believed the code was right; a review is supposed to check that
belief, and cannot if it shares it.

**And the properties were mutation-tested**, because a property that catches
nothing passes exactly like one that catches everything. Six of the seven rules
in the browser control were caught when disabled. The seventh was not, and
reading why turned out to be worth more than the six: a payment is refused by a
*different* rule than the one that names it, so the type check is defence in
depth rather than the load-bearing thing it looks like. That is a fact about
the control nobody had written down, and no amount of reading it had surfaced.

## What source cannot answer, and what that cost

Executable claims fixed one failure and property tests fixed a second. A third
survived both, and this audit walked into it within a day of publishing:
**every check in `verify.sh` and `verify-sweep.sh` reads a file, and a file
cannot tell you what is deployed.**

This report opened by stating that mainnet was restricted to its admin. It was,
when the sentence was written. An unrestricted replacement went up the same
afternoon. Exactly the shape of v4's error and v5's — and unreachable by
reading source more carefully, because the source was correct and the world had
moved.

So [verify-groups.py](../verification/verify-groups.py) reads groups that
executed. It answers *did the chain do this?* rather than *does the code say
this?*, and it is the only one of the three that can settle a question about a
deployment. It found nothing wrong with the contract. It found two things
nobody had written down — a fee taken only on ALGO hops, and a direct pool leg
sitting outside the co-signed floor — and it exposed a check in this
repository's own script that had been reporting a pass for the wrong reason
since the day it was written.

**What a trace cannot do** is show a control firing. Nobody attacked these
groups, so nothing needed refusing, and the negative claims — the ones that
matter — still rest on source and on `simulate`. It is the strongest available
evidence about what the deployment *is* and the weakest about how it behaves
under attack. [evidence/README.md §11](../evidence/README.md) says so at
length, because a trace is unusually good at looking like proof of more than it
is.

## Spending a deeper review

[ultrareview.md](ultrareview.md) plans where a multi-agent code review would
buy the most, and the answer is not the contract. The fix commits — every one
of which was certified by tests its own author wrote — the deployment scripts,
and this repository's own verifiers are the three targets, in that order.

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
