# Findings — v4 Smart Router Audit

This directory contains the detailed write-ups for every v4 finding (M1, L1, L2, I1, I2). Each finding file is self-contained and includes the location, code context, impact analysis, mitigation, and recommendation.

## Severity definitions

| Severity | Definition | Examples |
|----------|------------|----------|
| Critical | Direct theft of user funds, or permanent loss of contract funds | Reentrancy steal, signature bypass |
| High | Theft of accrued platform fees, or persistent DoS of the contract | Fee drain, floor bypass |
| Medium | Off-chain ↔ on-chain misalignment, persistent pool auth bypass, residual admin risk | Curve drift, factory migration |
| Low | Diagnostic, observability, or hardening issue | Silent zero-output, implicit trust |
| Informational | Hygiene, documentation, deployment policy | Unremoved template var, list widening policy |

## Verdict vocabulary

Every finding's `Status` field uses one of:

- **Patched** — code change applied in this audit cycle.
- **Patched (re-verified)** — code change applied in v1/v2/v3, re-verified for v4.
- **Verified Defended** — assert exists and is exercised; re-verified for v4.
- **Accepted by Design** — documented residual risk with rationale.
- **Documented Enhancement** — future work item, no code change required.
- **New in v4** — first identified in this audit cycle.

## Findings index

| ID | Severity | Title | Status | Source |
|----|----------|-------|--------|--------|
| [M1](M1-mwpt-weight-asymmetry-quoting.md) | Medium | MWPT weight-asymmetry quoting can drift from on-chain output | New in v4 | v4 |
| [L1](L1-mwpt-zero-output-branch.md) | Low | MWPT zero-output branch silently yields zero without reverting | New in v4 | v4 |
| [L2](L2-mwpt-vault-implicit.md) | Low | MWPT vault address is implicit (derived from pool params), not asserted | New in v4 | v4 |
| [I1](I1-restrict-to-admin-still-in-source.md) | Info | `RESTRICT_TO_ADMIN` template var still in source | New in v4 | v4 |
| [I2](I2-algofi-list-widening-policy.md) | Info | AlgoFi pool list widening policy undocumented | New in v4 | v4 |

## Regression index — v3 findings re-verified

All 19 v3 findings (C1, H1, M1–M6, L1–L5, I1–I7) were re-verified for v4. None regressed. See [REPORT.md](../REPORT.md) §4 for the full regression matrix and the re-verification method for each.

The v3 findings themselves are documented in `../router-audit-v3/findings/`. The v4 audit did not duplicate those write-ups.

## Reading order

For a first-time reader, we recommend:

1. Read this README to understand the structure.
2. Read [REPORT.md](../REPORT.md) §3 for the headline result.
3. Drill into M1 for the most material new finding.
4. Read L1 and L2 for the lower-severity MWPT observations.
5. Read I1 and I2 for deployment hygiene.
6. For background on the v3 findings that v4 retains, see `../router-audit-v3/findings/README.md`.
