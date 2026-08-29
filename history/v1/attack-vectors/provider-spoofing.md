# Provider Spoofing

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Caller names malicious Tinyman v2 pool address | Defended | Address is derived from validator + assets; no address in `Leg` |
| 2 | Caller names malicious Tinyman validator app ID | By design | Validator is a compile-time template variable |
| 3 | Caller names malicious Pact app ID | **Open** | No whitelist or factory check |
| 4 | Caller names malicious STAMM app ID | **Open** | No whitelist or factory check |
| 5 | Caller names malicious AlgoFi app ID | **Open** | No whitelist or factory check |
| 6 | Provider app is upgraded to malicious logic | Accepted | The router calls the app it is pointed at; upgrade risk is external |
| 7 | Pool returns unexpected output | Defended | Router measures its own balance delta, not pool logs |
| 8 | Pool reverts mid-route | Defended | Atomic group reverts all state changes |
