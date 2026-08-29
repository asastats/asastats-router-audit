# Provider-Specific Attack Vectors

This directory catalogs attack vectors specific to each external pool provider: Tinyman v2, Pact (constant-product + stableswap), STAMM, AlgoFi.

MWPT (Managed Weighted Pool) is a Pact sub-type and has its own dedicated file at [`../pact/mwpt.md`](../pact/mwpt.md).

## Files

- [`tinyman.md`](tinyman.md) — Tinyman v2 specific
- [`pact.md`](pact.md) — Pact constant-product / stableswap specific
- [`stamm.md`](stamm.md) — STAMM specific
- [`algofi.md`](algofi.md) — AlgoFi specific

## Coverage summary

| Provider | Vectors | Critical | High | Medium | Low | Defended | Notes |
|----------|--------:|---------:|-----:|-------:|----:|---------:|-------|
| Tinyman v2 | 10 | 0 | 0 | 0 | 0 | 10 | LogicSig hash derivation |
| Pact (CP+SS) | 15 | 0 | 0 | 0 | 0 | 15 | Creator pin |
| Pact MWPT | 27 | 0 | 0 | 1 | 2 | 21 | See [`../pact/mwpt.md`](../pact/mwpt.md) |
| STAMM | 15 | 0 | 0 | 0 | 0 | 15 | Creator pin + tier-merge |
| AlgoFi | 10 | 0 | 0 | 0 | 0 | 10 | Whitelist of 23 pools |
| **Total** | **77** | **0** | **0** | **1** | **2** | **71** | |
