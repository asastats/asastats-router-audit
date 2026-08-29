# Route Correctness

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Route cycle A → B → A | **Patched** | On-chain duplicate-asset check added |
| 2 | Duplicate asset in path | **Patched** | On-chain duplicate-asset check added |
| 3 | Multi-hop slippage drift | Mitigated | Global floor only; per-leg floors removed |
| 4 | Partial fill leaves caller with intermediate | Defended | Atomic group reverts on failure |
| 5 | Shared exit pool overestimated | Defended | `realised_outputs` telescopes shared pools |
| 6 | Leg input/output mismatch | Defended | `_swap_leg` uses `asset_in`/`asset_out` from route args |
| 7 | Stale quote executes | **Open** | No deadline parameter |
| 8 | Route exceeds 8 references | Defended | Off-chain `route_references` and `estimated_references` cap routes |
