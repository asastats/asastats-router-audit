# Inner Transactions

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Inner transaction pays a fee from router balance | Defended | All inner txns use `fee=0` |
| 2 | Inner transaction rekeys an account | Defended | No rekey fields are set |
| 3 | Inner transaction closes an account/holding | Defended | Close-outs are only to the caller or escrow, not arbitrary |
| 4 | Cross-app call re-enters router | Not applicable | AVM rejects re-entry to app on call stack |
| 5 | Malicious pool manipulates shared state | Accepted | Pool can only affect its own state and the router's balance |
| 6 | Caller uses non-STAMM `opups` to waste budget | **Patched** | Now asserted zero for non-STAMM |
| 7 | STAMM budget call omitted | Defended | Off-chain builder includes it; contract asserts enough budget by simulation |
| 8 | Resource array omits required app/asset/account | Defended | Off-chain `route_references` gathers them; chain rejects unnamed resources |
