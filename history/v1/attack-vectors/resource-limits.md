# Resource Limits

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Opcode budget exhausted on wide split | Mitigated | `pool_budget` call adds budget; measured margin remains |
| 2 | STAMM swap exceeds budget | Defended | `Leg.opups` buys budget; measured against mainnet |
| 3 | Group size exceeds 16 | Defended | `router.build.assemble` enforces limit |
| 4 | Transaction references exceed 8 | Defended | `route_references` counts; three-leg STAMM routes are dropped |
| 5 | MBR drained via junk opt-ins | Defended | `opt_in_asset` requires a route in the same group |
| 6 | Float exhausted by repeated routes | Defended | Opt-ins are closed in the same group; float is borrowed, not spent |
| 7 | Box/storage DoS | Not applicable | Router uses no boxes or local state |
