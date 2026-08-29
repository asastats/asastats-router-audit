# Arithmetic

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Overflow in fee skim | Defended | `fee_bps <= 100`, amount is a balance delta; Puya uses safe arithmetic |
| 2 | Underflow in balance delta | Defended | `_held` returns opted-in balance; `_swap_leg` computes after - before |
| 3 | Precision loss across multi-hop route | Mitigated | Global floor protects final output; per-leg floors removed |
| 4 | Slippage drift across hops | Mitigated | Only final output is checked against `minimum_received` |
| 5 | Fee compounding on three-leg route | Defended | Fee skim is taken once, on the first ALGO hop |
| 6 | Dust accumulation in router | Defended | Opened holdings are closed in the same group |
| 7 | `minimum_received` rounding above quote | Defended | `minimum_received` is rounded down in `router.quote` |
| 8 | `convert_and_distribute` batch bounds bypass | Defended | `batch <= accrued`, `batch >= MIN` or `== accrued`, `batch <= MAX` |
