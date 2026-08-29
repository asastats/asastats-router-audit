# Complete Findings Registry (v5)

This directory contains the inventory of all 23 security findings, tracking their origin, severity, remediation status, and verification evidence for the ASA Stats Smart Router.

> **Amended 2026-08-29.** `I2` was issued as VERIFIED SAFE and was not: the
> unpriced-forfeit branch had no value test. `I1` was rewritten because its
> only evidence was a test written in the commit under audit. See
> [../CORRECTIONS.md](../CORRECTIONS.md).

---

## Findings Summary Matrix

| Finding ID | Severity | Title | Origin | Status (v5) |
|:----------:|:--------:|-------|:------:|:-----------:|
| **`C1`** | Critical | Permissionless `convert_and_distribute` drains accrued fees | v1 | **REMEDIATED** |
| **`H1`** | High | Frontend-controlled floor permits zero-floor slippage theft | v1 | **REMEDIATED** |
| **`M1`** | Medium | Route paths not sanitized for duplicate/cycling assets | v1 | **REMEDIATED** |
| **`M2`** | Medium | Funding transaction adjacency not enforced | v2 | **REMEDIATED** |
| **`M3`** | Medium | Pre-held ASA input conservation not enforced | v2 | **REMEDIATED** |
| **`M4`** | Medium | External provider pool applications not authenticated | v1 | **REMEDIATED** |
| **`M5`** | Medium | Unbounded STAMM opup requests by callers | v3 | **REMEDIATED** |
| **`M6`** | Medium | Same-group conversion pool approval and execution | v3 | **REMEDIATED** |
| **`M7`** | Medium | MWPT asymmetric weight quoting precision drift | v4 | **REMEDIATED** |
| **`L1`** | Low | Application deletion asset holdings check | v1 | **REMEDIATED** |
| **`L2`** | Low | Zero-address rejection in administrative setters | v1 | **REMEDIATED** |
| **`L3`** | Low | Reentrancy guard structural verification | v1 | **VERIFIED SAFE** |
| **`L4`** | Low | Conversion minimum output floor bounding | v1 | **REMEDIATED** |
| **`L5`** | Low | Voucher signer key rotation and revocation | v1 | **VERIFIED SAFE** |
| **`L6`** | Low | MWPT zero output branch handling | v4 | **VERIFIED SAFE** |
| **`L7`** | Low | MWPT dynamic on-chain vault assertion | v4 | **REMEDIATED** |
| **`I1`** | Info | Liquid staking rate oracle boundary policy | v5 | **VERIFIED SAFE** (rewritten 2026-08-29) |
| **`I2`** | Info | Dust sweep portfolio classification policy | v5 | **GAP FOUND, REMEDIATED** `1c128f2` |
| **`I3`** | Info | Dead code removal for non-STAMM opups | v3 | **REMEDIATED** |
| **`I4`** | Info | Dynamic minimum balance handling | v3 | **VERIFIED SAFE** |
| **`I5`** | Info | Unbound admin conversion batch repetition | v3 | **ACCEPTED BY DESIGN** |
| **`I6`** | Info | STAMM multi-tier ABI execution alignment | v3 | **VERIFIED SAFE** |
| **`I7`** | Info | AlgoFi defunct pool list curation policy | v3 | **ACCEPTED BY DESIGN** |
