# Smart Router Security Audit — v5

A comprehensive, production-grade security audit of the ASA Stats Smart Router smart contract (`router/contracts/router_app.py`) and associated execution engine, incorporating the **latest mainnet deployment (App ID `3688554446`)**, testnet deployment (`770123816`), full **Pact MWPT (Managed Weighted Pool)** on-chain dynamic vault integration, **liquid staking rate pricing**, and the end-to-end **dust sweep subsystem**.

The methodology directly synthesizes the LiquiHog STAMM AMM Audit (`audit/STAMM-AI-AUDIT-main/`, 121 attack vectors), three independent meta-analyses (`analysis1.md`, `analysis2.md`, `analysis3.md`), the formal Algorand Router Audit Plan (`audit/router-audit-v3/algorand-amm-router-audit-plan.md`), the Trail of Bits Algorand Vulnerability Scanner (`algorand-vulnerability-scanner/`), and the evolution through router audits v1, v2, v3, and v4.

**Overall Verdict:** **NO CRITICAL OR HIGH-SEVERITY VULNERABILITIES FOUND IN THE CONTRACT.** All prior findings from v1–v4 are verified as patched, mitigated, or defended by design. This is **not** a clearance for unrestricted public deployment — see [CORRECTIONS.md](CORRECTIONS.md) and the restriction row below.

> **This document was amended on 2026-08-29 after review.** It contained errors,
> one of them safety-critical: it recorded `RESTRICT_TO_ADMIN` as having been
> removed from the live mainnet application, which never happened, and
> recommended unrestricted production use on that basis. Every correction is
> listed in [CORRECTIONS.md](CORRECTIONS.md).

---

## Key Highlights of Audit v5

| Dimension | v4 Baseline | v5 Audit Status |
|-----------|-------------|-----------------|
| **Active Mainnet Deployment** | App ID `3680942699` | **App ID `3688554446`** (Commit `ca58dd6` / `04c999a`) |
| **Active Testnet Deployment** | App ID `769636397` | **App ID `770123816`** |
| **Pact MWPT Vault Integration** | Quoter-supplied; implicit on-chain | **Fully verified on-chain** via `AppGlobal.get_ex_uint64(pool_app, b"vault")` & deposit directed to vault escrow |
| **Access control** | Compiled with `RESTRICT_TO_ADMIN` | **Still compiled with `RESTRICT_TO_ADMIN`** — `3688554446` refuses every caller but the admin. Manifest `RESTRICT_TO_ADMIN = 1`; the engine returns 503 for any other caller |
| **Liquid Staking Asset Pricing** | Unpriced tail fallback | **Real pools first, protocol rate as fallback** (`router/selection.py`, commit `75087b8`) |
| **Dust Sweep Architecture** | Separate prototype | **Production sweep & classification engine** (`router/sweep.py`; 323 tests across the four suites — see CORRECTIONS.md) |
| **Static Analysis (Tealer)** | 4,657 TEAL lines | **4,681 TEAL lines**, swept-TEAL digest `1761d970954e4d7e` (not the deployed hash — see REPORT.md), 0 exploitable findings |
| **Test Suite Coverage** | 400+ test cases | **934 router tests passing** at the audited revision |

---

## Where to Find What

| Document | Description |
|----------|-------------|
| [IS-IT-SAFE.md](IS-IT-SAFE.md) | Plain-English security assessment, threat summaries, and user FAQ |
| [REPORT.md](REPORT.md) | Full consolidated technical audit report and architectural verification |
| [SECURITY.md](SECURITY.md) | Formal threat model, trust boundaries, and operational runbook |
| [IMPROVEMENTS.md](IMPROVEMENTS.md) | Contract and engine improvements, code optimization history |
| [DISCLAIMER.md](DISCLAIMER.md) | Scope boundaries, verification assumptions, and AI audit limitations |
| [findings/](findings/) | Complete repository of all 23 findings (C1, H1, M1–M7, L1–L7, I1–I7) with full verification status |
| [attack-vectors/](attack-vectors/) | Exhaustive 161-vector matrix across general, route, provider, and pact/mwpt domains |
| [contracts/](contracts/) | Line-by-line smart contract state keys, entry points, and cross-contract call graphs |
| [methodology/](methodology/) | Audit plan, scope, formal invariants, comparison vs STAMM, and independent analyses |
| [tools/](tools/) | Tealer static analysis sweep outputs and Trail of Bits vulnerability scanner evaluations |

---

## Contracts in Scope

| Component | Source Path | TEAL Lines | Role & Description |
|-----------|-------------|------------|---------------------|
| **Router Approval Program** | `router/contracts/router_app.py` | 4,681 | Multi-hop routing, provider dispatch, fee skimming, floor enforcement |
| **Router Clear-State Program** | `router/contracts/router_app.py` | 7 | Minimal `pushint 1; return` (safe, no state leaks) |
| **Core Quoter & Curves** | `router/quote.py`, `router/curves.py` | — | Off-chain exact pricing, Newton-Raphson stableswap & MWPT curves |
| **Leg Builder & Venues** | `router/legs.py`, `router/venues.py` | — | Group construction, reference packing, creator validation |
| **Dust Sweep System** | `router/sweep.py`, `scripts/dustsweep.py` | — | Portfolio asset classification, forfeit/convert/close planning |
| **Deployment & Verification** | `scripts/deploy.py`, `scripts/verify_deployment.py` | — | Bytecode matching, template substitution, state verification |

---

## Audit Lineage & Evolution

```
v1 (2026-08-11) ──► Initial audit: C1 (convert_and_distribute pool drain) & H1 (widget floor zero)
        │
v2 (2026-08-13) ──► Signed floor architecture, pre-held ASA conservation, group hygiene
        │
v3 (2026-08-15) ──► Synthesis of 134 attack vectors, ToB 11-pattern scanner, formal invariant plan
        │
v4 (2026-08-22) ──► Initial Pact MWPT weighted pool integration, quoter weight-asymmetry analysis
        │
v5 (2026-08-29) ──► Deployment 3688554446, On-chain MWPT vault verification, Liquid staking pricing,
                    Full dust sweep subsystem, 934+ verified tests, 161 attack vectors, Tealer sweep clean
```
