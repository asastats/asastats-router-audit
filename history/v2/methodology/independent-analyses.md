# Synthesis of Independent Analyses

## STAMM audit repository

The STAMM repository demonstrates a useful process: enumerate attack vectors,
trace every arithmetic and state mutation site, state explicit invariants, and
separate defended, by-design, admin-controlled and accepted outcomes. Its
scope is primarily a system whose pool, factory, registry and governance
contracts are controlled together.

The router cannot inherit the STAMM verdict. It delegates execution to
external AMMs, so the analogous question is not only whether the router math is
correct, but what happens when a called application is stale, incompatible,
malicious or differently ordered.

## Analysis 1

Analysis 1 highlighted Algorand-specific MBR draining, opcode budget and group
limits, application-ID spoofing, fee pooling, dust, and inner-transaction
isolation. These map directly to the router's temporary opt-in handshake,
`Leg.opups`, eight-reference ceiling, provider pins, zero inner fees and
balance-delta measurement.

Its main limitation is that it describes risks generically. The router review
therefore checked each item against actual resource arrays and transaction
construction rather than recording a checklist as a verdict.

## Analysis 2

Analysis 2 recommended extending the pool-centric STAMM matrix with aggregator
vectors: multi-hop conservation, external-call failure, temporary holdings,
deadline/slippage, factory authentication, arithmetic bounds, differential
testing, Hypothesis fuzzing, compiler pinning and KAVM modelling.

It also correctly treated ARC-4 validation, close/rekey fields, foreign arrays,
inner fees, compiler behavior and formal invariants as first-class Algorand
concerns. This v2 audit adopts those as coverage categories, while recording
that KAVM and fuzzing remain incomplete rather than implying they were done.

## Analysis 3

Analysis 3 added less obvious aggregator failures: state desynchronization,
cross-hop slippage drift, liquidity mirages, cycles, cross-user balance
contamination, failure atomicity, external upgrade risk, non-standard assets,
box DoS, differential testing and malicious-pool harnesses.

The review confirmed that balance deltas, global floors, route sanitisation and
atomic groups address several of these. It retained provider-code authenticity,
pre-held balance conservation and malicious resource behavior as residual
review items. It also treated the suggested reentrancy guard carefully:
Algorand's AVM call-stack rules make EVM-style callback reentrancy inapplicable
here, so no unnecessary state lock was added.

## Resulting methodology

The combined material produced this priority order:

1. Prove the signed floor and all transaction references bind to the exact
   group the user submits.
2. Prove no input, intermediate, output, fee or temporary minimum balance is
   stranded across two- and three-hop routes.
3. Bound every external application, resource reference and opcode source.
4. Review the release signing path separately from unsigned simulation.
5. Distinguish caller-fund risk, float availability, treasury risk and
   provider/admin trust instead of collapsing them into one severity.
