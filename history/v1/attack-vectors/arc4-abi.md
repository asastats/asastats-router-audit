# ARC-4 / ABI

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Malformed ARC-4 arguments panic | Defended | Puya >= 5.3.2 validates encoding by default |
| 2 | Unknown method selector executed | Defended | `ARC4Contract` dispatches and rejects unknown selectors |
| 3 | `verify_discount` byte[] length underflow | Defended | `assert voucher.length == VOUCHER_LENGTH` |
| 4 | Hand-written signatures drift from ABI | Defended | `TestTheHandWrittenSignatures` pins them |
| 5 | Typed transaction references misused | Defended | `_input_amount` validates sender, receiver, asset |
| 6 | Return-value log prefix spoofed | Defended | `_logged_output` checks the ARC-4 prefix |
