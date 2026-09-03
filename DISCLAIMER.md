# Disclaimer

## This audit was produced by an AI system

Not assisted by one — produced by one. A large language model read the
contract, ran the checks, and wrote these documents. A human commissioned it,
supplied the environment, and has read the result.

**No human with Algorand smart-contract experience has reviewed this work.**
That is the single most important sentence in this repository.

Until 2026-08-30 it was also the reason the mainnet deployment was compiled
with `RESTRICT_TO_ADMIN`. That restriction is now off, and `3692588382` serves
the public. **The sentence above did not stop being true; it stopped being
cushioned.** While the admin was the only caller, an audit nobody qualified had
read was a tolerable risk to one account. It is now a risk to everyone who
routes through it, and what bounds that is not this document — it is
`set_paused`, which stops routing in one transaction and does not depend on any
of this analysis being correct.

## Why we are unusually blunt about it

This is the sixth audit of this contract. The five before it were also
AI-produced, and the failure mode is now documented rather than theoretical:

- **v4** recommended removing `RESTRICT_TO_ADMIN` on the grounds that "mainnet
  has been running unrestricted for months". Mainnet was the restricted one.
  The application id it cited as evidence was the *testnet* deployment.
- **v5** recorded the removal of `RESTRICT_TO_ADMIN` from mainnet
  `3688554446` as an improvement already delivered. It never happened; that
  application's manifest records `RESTRICT_TO_ADMIN = 1`. On the strength of
  that, its plain-English summary opened "secure for unrestricted mainnet
  production deployment."
- **v5** also cited "982 test cases" for a file that collects 111, and marked
  a finding "verified safe" without reading the predicate that decided it —
  which turned out to contain a real defect.
- **v6 — this one — described a mainnet deployment that had been replaced the
  same afternoon.** It opened by saying the contract was restricted to its
  admin. `3689591968` went up unrestricted on 2026-08-30, hours later. Same
  class of error as the two above: a statement about a running system, made
  from a document. Corrected on 2026-09-01, and answered permanently by
  [evidence/](evidence/) and `verify-groups.py`, which read transactions rather
  than prose.

Each of those is the same failure: **fluent text asserting something nobody
checked.** An AI audit is good at reading a lot of code quickly and at
noticing shapes. It is bad at knowing when it does not know, and the output
does not look any different when it is wrong.

## What this audit did differently

Every factual claim in [REPORT.md](REPORT.md) is backed by a command, and the
recorded output of each script is committed alongside it. 191 checks across
three: [verify.sh](verification/verify.sh) reads the contract's source,
[verify-sweep.sh](verification/verify-sweep.sh) reads the sweep's off-chain
estate, and [verify-groups.py](verification/verify-groups.py) reads seven
groups that executed on mainnet. If a claim is not in one of them, it is not
verified, and [REPORT.md §5](REPORT.md) lists what was deliberately left
unchecked.

The third script exists because of the error listed above. Source checks cannot
answer questions about a running system, and the three worst mistakes this
series has made — twice by earlier audits, once by this one — were all of that
kind.

That makes the audit *falsifiable*. It does not make it correct. One of these
scripts had been giving a false answer since the day it was written, in a way
that read exactly like a pass, and only a second test account found it; see
[evidence/README.md §10](evidence/README.md).

## What this is not

- **Not a guarantee.** No audit is, and this one less than most.
- **Not a substitute for a professional human audit.** If real user funds are
  going to be exposed to this contract, commission one.
- **Not a review of the AMMs the router calls.** Tinyman, Pact, STAMM and
  AlgoFi are trusted to behave as documented.
- **Not a review of key management, deployment operations, or the off-chain
  quoter's pricing.** A co-signed floor protects the trade; whether the floor
  is a *good* number is a different question, out of scope here.

## Use of this repository

Published so that the reasoning can be checked, disagreed with, and improved.
Findings, corrections and counter-examples are welcome — particularly from
anyone who has written Algorand contracts in anger.

Nothing here is financial advice, and no warranty is given or implied.
