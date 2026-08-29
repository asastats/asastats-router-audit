# Methodology — Smart Router v4 Audit

This directory documents the methodology used in the v4 audit: scope, coverage, glossary, audit plan, and how it differs from the prior STAMM-pool-centric methodology.

## Files

- [`scope.md`](scope.md) — In-scope and out-of-scope items; source identification.
- [`audit-coverage.md`](audit-coverage.md) — What was checked; attack vector statistics; test tier coverage.
- [`glossary.md`](glossary.md) — Definitions for protocol-specific terms.
- [`audit-plan.md`](audit-plan.md) — The planned audit steps (phases 0–7), adapted from the v3 plan.
- [`independent-analyses.md`](independent-analyses.md) — How the three independent analyses (`analysis1.md`, `analysis2.md`, `analysis3.md`) were incorporated.
- [`vs-stamm.md`](vs-stamm.md) — How this audit differs from the STAMM pool audit at `<audit>/STAMM-AI-AUDIT-main/`.

## Methodology lineage

The v4 audit inherits its methodology from:

1. **STAMM AMM Audit** (`<audit>/STAMM-AI-AUDIT-main/`) — 121-vector methodology, five-term verdict vocabulary, evidence-based findings format.
2. **Three independent analyses** (`<audit>/analysis1.md`, `analysis2.md`, `analysis3.md`) — gaps and improvements for cross-AMM aggregators.
3. **v3 audit plan** (`<audit>/router-audit-v3/algorand-amm-router-audit-plan.md`) — 7-phase plan adapted from Runtime Verification / Ulam Labs / Trail of Bits.
4. **Trail of Bits Algorand vulnerability scanner** (`<audit>/router-audit-v3/algorand-vulnerability-scanner/SKILL.md`) — 11-pattern checklist.

The v4 audit *adds* the Pact MWPT integration as a new attack surface, while preserving all prior guarantees.

## Key methodology choices

1. **Verdict vocabulary** is preserved from STAMM (Defended, Not applicable, By design, Admin-controlled, Accepted) and extended with three new statuses for findings: Patched (re-verified), Verified Defended (re-confirmed), Accepted by Design (re-confirmed).
2. **Attack vectors** are split into 4 subdirectories by attack surface (general, route, provider, pact/MWPT) for easier navigation.
3. **Findings** are numbered by severity (M1, L1, L2, I1, I2), with one file per finding. The v3 findings are *referenced* but not re-written in this directory.
4. **Test coverage** is documented in 5 tiers (offline deterministic, LocalNet integration, mainnet state, testnet deployment, static analysis). All tiers were re-run as part of the v4 audit preparation.
5. **Tooling** is documented separately in [`../tools/`](../tools/), with `tealer-results.md` and `scanner-results.md`.
