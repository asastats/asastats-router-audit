# General Attack Vectors

This directory catalogs ~50 attack vectors that apply to the router regardless of provider. They cover group-transaction manipulation, MBR draining, reentrancy-style execution, resource limits, and deployment considerations.

## Files in this subdirectory

- [`group-transactions.md`](group-transactions.md) — group-level attacks (rekey, close, padding, ordering)
- [`mbr.md`](mbr.md) — minimum balance requirement draining
- [`reentrancy.md`](reentrancy.md) — reentrancy-style execution via inner transactions
- [`resource-limits.md`](resource-limits.md) — opcode budget, box exhaustion, fee pooling
- [`deployment.md`](deployment.md) — deployment-time concerns (compiler, template vars)
- [`economic.md`](economic.md) — economic / MEV vectors

## Coverage

These vectors were inherited from v3 (with re-verification) and supplemented with new v4-specific concerns. The headline results:

| Vector category | Critical | High | Medium | Low | Defended | By design | N/A | Accepted |
|-----------------|---------:|-----:|-------:|----:|---------:|----------:|----:|---------:|
| Group transactions | 0 | 0 | 0 | 0 | 18 | 0 | 2 | 0 |
| MBR draining | 0 | 0 | 0 | 0 | 6 | 0 | 0 | 0 |
| Reentrancy | 0 | 0 | 0 | 1 | 4 | 0 | 0 | 1 |
| Resource limits | 0 | 0 | 0 | 0 | 8 | 0 | 0 | 0 |
| Deployment | 0 | 0 | 0 | 0 | 4 | 0 | 0 | 1 |
| Economic | 0 | 0 | 0 | 0 | 2 | 3 | 4 | 0 |
| **Total** | **0** | **0** | **0** | **1** | **42** | **3** | **6** | **2** |

The L3 finding (reentrancy-style analysis) is documented at [`../../findings/`](../findings/) but was inherited from v3 and is accepted by design. The L1 finding in reentrancy is local-frame accounting, which is the v3 finding.
