# Disclaimer

## This audit was produced by an AI system

Not assisted by one — produced by one. A large language model read the
contract, ran the checks, and wrote these documents. A human commissioned it,
supplied the environment, and has read the result.

**No human with Algorand smart-contract experience has reviewed this work.**
That is the single most important sentence in this repository, and it is the
reason the mainnet deployment is still compiled with `RESTRICT_TO_ADMIN`.

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

Each of those is the same failure: **fluent text asserting something nobody
checked.** An AI audit is good at reading a lot of code quickly and at
noticing shapes. It is bad at knowing when it does not know, and the output
does not look any different when it is wrong.

## What this audit did differently

Every factual claim in [REPORT.md](REPORT.md) is backed by a command in
[verification/verify.sh](verification/verify.sh), and the recorded output of
that script is committed alongside it. 27 checks. If a claim is not in there,
it is not verified, and [REPORT.md §5](REPORT.md) lists what was deliberately
left unchecked.

That makes the audit *falsifiable*. It does not make it correct.

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
