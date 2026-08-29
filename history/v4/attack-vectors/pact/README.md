# Pact Attack Vectors (Combined)

This directory catalogs attack vectors specific to Pact pools. The Pact provider has three sub-types:

1. **Constant-product (CP)** — traditional `x * y = k` AMM
2. **Stableswap (SS)** — designed for pegged assets with high amplification factor
3. **MWPT (Managed Weighted Pool)** — weighted reserves with separate vault reference

The constant-product and stableswap vectors are in [`../provider/pact.md`](../provider/pact.md). The MWPT vectors (the v4 addition) are in [`mwpt.md`](mwpt.md).

## File map

| File | Sub-type | Vectors | Notes |
|------|----------|--------:|-------|
| [`../provider/pact.md`](../provider/pact.md) | CP + SS | 15 | Inherited from v3 |
| [`mwpt.md`](mwpt.md) | MWPT | 27 | New in v4 |

## Cross-references

- v3 audit findings: [`../../router-audit-v3/findings/`](../../router-audit-v3/findings/) (M4, M5)
- v4 findings: [`../../findings/`](../../findings/) (M1, L1, L2)
- Off-chain code: `router/curves.py:pact_out`, `router/curves.py:pact_stableswap_out`, `router/curves.py:pact_mwpt_out`
- On-chain code: `router/contracts/router_app.py:_pact_leg` (selector branch on pool creator)
