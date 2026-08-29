# Conversion / Treasury

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Caller swaps fees through malicious pool | **Patched** | `convert_and_distribute` is now admin-only |
| 2 | Caller sets `minimum_out = 0` and steals fees | **Patched** | Admin-only + proposed `minimum_out > 0` |
| 3 | Batch exceeds accrued amount | Defended | `assert batch <= self.accrued` |
| 4 | Batch below economic floor | Defended | `assert batch >= MIN or batch == accrued` |
| 5 | Batch above impact ceiling | Defended | `assert batch <= MAX_CONVERSION_BATCH` |
| 6 | Admin sets escrow to non-opted-in account | Defended | `set_escrow` checks ASASTATS balance |
| 7 | Admin drains escrow after conversion | Admin-controlled | Escrow receives the converted ASASTATS |
