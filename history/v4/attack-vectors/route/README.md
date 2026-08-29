# Route Attack Vectors

This directory catalogs ~25 attack vectors related to the route itself: path validation, multi-hop correctness, slippage enforcement, and value conservation across hops.

## Files

- [`path-validation.md`](path-validation.md) — path sanitization, cycles, duplicates
- [`conservation.md`](conservation.md) — value conservation across multi-hop
- [`slippage.md`](slippage.md) — slippage enforcement (floor mechanism)
- [`mhop.md`](mhop.md) — multi-hop correctness

## Coverage

These vectors were inherited from v3 with re-verification. No new route-level findings in v4.

| Vector category | Critical | High | Medium | Low | Defended | By design | N/A | Accepted |
|-----------------|---------:|-----:|-------:|----:|---------:|----------:|----:|---------:|
| Path validation | 0 | 0 | 0 | 0 | 8 | 0 | 0 | 0 |
| Conservation | 0 | 0 | 0 | 0 | 6 | 0 | 0 | 0 |
| Slippage | 0 | 0 | 0 | 0 | 5 | 0 | 0 | 0 |
| Multi-hop | 0 | 0 | 0 | 0 | 6 | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** | **0** | **25** | **0** | **0** | **0** |
