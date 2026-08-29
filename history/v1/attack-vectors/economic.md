# Economic

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Sandwich attack on a route | Not applicable | Algorand has no public mempool or tx reordering |
| 2 | Flash-loan style manipulation | Mitigated | No flash-loan primitive; pools read state at execution time |
| 3 | Donation to router to distort pricing | Accepted | Donation would be locked unless it matches an opened holding |
| 4 | Fee evasion by routing through non-ALGO intermediate | By design | `_skim` only runs on ALGO hops; documented revenue gap |
| 5 | Keeper fails to convert fees | **Patched** | Method was permissionless; now admin-only (keeper can be admin) |
| 6 | Sandwich on fee conversion | Defended | `MAX_CONVERSION_BATCH` bounds extractable value |
