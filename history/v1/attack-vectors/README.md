# Attack Vector Analysis

This directory contains a router-specific attack-vector matrix, modelled on the STAMM audit's 121-vector taxonomy but adapted for an **aggregator/router that calls untrusted external contracts**.

## Verdict glossary

| Verdict | Meaning |
|---------|---------|
| **Defended** | The contract has a specific guard that prevents the attack. |
| **Mitigated** | The attack is made impractical or bounded by design. |
| **Not applicable** | The attack does not apply to this architecture. |
| **Admin-controlled** | The attack requires admin compromise or is an accepted admin power. |
| **Accepted** | Known residual risk, documented and accepted. |
| **Open** | A finding that needs a code change or further analysis. |

## Matrix

| Category | Vectors | Result |
|----------|---------|--------|
| [Access control](access-control.md) | Admin escalation, fee ceiling, voucher signer, restrict flag | All Defended / Admin-controlled |
| [Group transactions](group-transactions.md) | Rekey/close, padding, fee pooling, ordering, duplicates | Defended / Accepted |
| [Inner transactions](inner-transactions.md) | Fee=0, resource arrays, cross-app calls, budget | Defended / Open |
| [Arithmetic](arithmetic.md) | Fee skim, rounding, overflow, multi-hop precision | Defended / Accepted |
| [Provider spoofing](provider-spoofing.md) | Tinyman derivation, Pact/STAMM/AlgoFi app IDs | Mixed: Tinyman Defended, others Open |
| [Route correctness](route-correctness.md) | Cycles, slippage drift, atomicity, shared pools | Mitigated / Open |
| [Resource limits](resource-limits.md) | Opcode budget, group size, 8 references, MBR | Defended / Mitigated |
| [Economic](economic.md) | Sandwich, MEV, donation, fee evasion | Not applicable / Bounded |
| [Conversion / treasury](conversion-treasury.md) | Pool choice, batch bounds, accrued accounting | Open → Patched |
| [ARC-4 / ABI](arc4-abi.md) | Encoding, selectors, typed txn refs | Defended |

## Key insight

The STAMM audit asked "Is my math correct?" The router audit must ask "What if every external pool lies, breaks assumptions, or behaves differently?" This matrix reflects that shift.
