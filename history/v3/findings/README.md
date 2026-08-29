# Security Findings Repository (v3)

## Findings Index

| ID | Severity | Category | Title | Status |
|---|---|---|---|---|
| **C1** | Critical | Treasury Safety | Permissionless `convert_and_distribute` with caller-supplied pool drains accrued fees | **Patched** |
| **H1** | High | Economic / Slippage | Quote floor authorization requires backend signature | **Patched** |
| **M1** | Medium | Route Correctness | Route path sanitization (cycles and duplicate assets) | **Patched** |
| **M2** | Medium | Accounting | Funding transaction adjacency requirement | **Patched** |
| **M3** | Medium | Accounting | Pre-held ASA input conservation verification | **Patched** |
| **M4** | Medium | Trust Boundary | External provider pool authentication (creator pinning & whitelisting) | **Patched / Accepted** |
| **M5** | Medium | Resource Safety | Unbounded STAMM opups & non-STAMM budget calls | **Patched** |
| **M6** | Medium | Operations | Same-group conversion pool approval separation | **Patched** |
| **L1** | Low | Application Lifecycle | `delete_application` explicit held ASA check | **Patched** |
| **L2** | Low | Access Control | Zero-address checks on `set_admin` and `set_escrow` | **Patched** |
| **L3** | Low | Composability | Reentrancy-style execution phase analysis | **Documented / Accepted** |
| **L4** | Low | Treasury Safety | `convert_and_distribute` minimum output enforcement | **Patched** |
| **L5** | Low | Cryptography | Voucher signer key separation and rotation | **Documented / Accepted** |
| **I1** | Info | Code Quality | Dead code in `_swap_leg` non-STAMM budget call | **Patched in v3** |
| **I2** | Info | Protocol | Quote authorization application call type pinning | **Patched** |
| **I3** | Info | ABI | ARC-4 dynamic array encoding length checks | **Documented** |
| **I4** | Info | AVM Platform | Dynamic minimum balance calculation | **Documented** |
| **I5** | Info | Governance | Unbounded admin batch repetition for fee conversions | **Documented / Accepted** |
| **I6** | Info | Efficiency | STAMM multi-tier split execution in single transaction | **Documented** |
| **I7** | Info | Protocol | Defunct AlgoFi pool liquidity curation | **Documented** |
