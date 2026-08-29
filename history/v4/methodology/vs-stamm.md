# v4 Audit vs. STAMM AMM Audit — Methodology Comparison

The STAMM AMM Audit at `<audit>/STAMM-AI-AUDIT-main/` audited a pool contract — a self-contained AMM that holds reserves and executes swaps. The v4 Smart Router audit audited a *cross-pool aggregator* — a contract that orchestrates swaps across multiple external pools. The two audit targets have different security properties and require different methodologies.

## Side-by-side comparison

| Dimension | STAMM AMM | v4 Smart Router |
|-----------|-----------|-----------------|
| **Target type** | Self-contained pool | Cross-pool aggregator |
| **External calls** | None (self-contained) | Many (Tinyman v2, Pact CP/MWPT, STAMM, AlgoFi) |
| **Authentication surface** | n/a (no external calls) | Pool creator pin / whitelist / LogicSig hash |
| **Multi-hop correctness** | Internal routing across tiers | Routing across heterogeneous external pools |
| **Slippage model** | Per-operation `min_out` parameter | Backend-signed floor on the transaction note |
| **Conservation model** | K-invariant enforced per swap | Balance-delta measurement across hops |
| **Treasury model** | Tier-P protocol fees | `convert_and_distribute` to ASASTATS |
| **Admin actions** | Governor via timelock | Direct setters (`set_admin`, `set_fee`, etc.) |
| **Update/Delete model** | Blocked | Blocked (Update); admin-only with assertions (Delete) |
| **Test surface** | Pure-Python Beaker tests | Beaker + Hypothesis fuzz + LocalNet integration + mainnet-state |

## Methodologies

### STAMM AMM methodology

The STAMM audit follows a 4-phase methodology (per `audit-coverage.md`):

1. **Phase 1:** Initial assessment — methods, math/asset flows, security properties.
2. **Phase 2:** Deep verification — core math subroutines, state consistency, ALGO path, hook.
3. **Phase 3:** Adversarial analysis — edge cases, multi-position routing, governance, group txn.
4. **Phase 4:** Exhaustive arithmetic — every multiply, every subtract, every `app_global_put`, every assert.

This is appropriate for a self-contained pool: the math is the main attack surface, and exhaustive enumeration is feasible.

### v4 Smart Router methodology

The v4 audit follows a 7-phase methodology (per [`audit-plan.md`](audit-plan.md)):

1. **Phase 0:** Scoping and preparation.
2. **Phase 1:** Automated static analysis (Tealer + Trail of Bits).
3. **Phase 2:** Manual line-by-line review (Algorand/AVM checklist).
4. **Phase 3:** Router/AMM business-logic review (path validation, atomicity, slippage, rounding, reentrancy-analogue).
5. **Phase 4:** Dynamic / simulation testing.
6. **Phase 5:** AI-assisted second pass.
7. **Phase 6:** Reporting and remediation.
8. **Phase 7:** Post-deployment.

This is appropriate for a cross-pool aggregator: the attack surface is *external pool behaviour*, not internal math. Exhaustive enumeration is infeasible (each external pool is a black box), so the methodology emphasises authentication, validation, and adversarial simulation.

## What the v4 audit borrows from STAMM

1. **Five-term verdict vocabulary** — Defended, Not applicable, By design, Admin-controlled, Accepted. Same as STAMM.
2. **Findings file structure** — one file per finding (M, L, I) with severity, status, location, code excerpt, impact, recommendation, cross-references. Same as STAMM.
3. **Attack-vectors per-category** — subdirectories per attack surface. Same structure as STAMM's `attack-vectors/{pool,admin,factory,registry}/`.
4. **Methodology subdirectory** — `scope.md`, `audit-coverage.md`, `glossary.md`, plus `audit-plan.md` and `independent-analyses.md`.
5. **State keys and cross-contract interactions** — per-contract analysis of global state and call graph. Adapted for the router's single-contract structure.
6. **Five-term status vocabulary for findings** — Patched (re-verified), Verified Defended (re-confirmed), Accepted by Design (re-confirmed), Documented Enhancement, New in v4.

## What the v4 audit adds beyond STAMM

1. **Per-attack-surface subdirectories** for attack vectors (`general/`, `route/`, `provider/`, `pact/`).
2. **Provider-specific attack surfaces** — 5 providers (Tinyman v2, Pact CP, Pact MWPT, STAMM, AlgoFi), each with its own attack vector file.
3. **MWPT-specific attack vectors** — 27 new vectors for the weighted-pool integration.
4. **Three improvements** documented in `IMPROVEMENTS.md` (rewriting MWPT curve math, adding vault assert, removing `RESTRICT_TO_ADMIN`).
5. **Tool results subdirectory** — `tools/tealer-results.md`, `tools/scanner-results.md` for static-analysis outputs.
6. **Independent analyses** — `methodology/independent-analyses.md` documents how `analysis1.md`, `analysis2.md`, `analysis3.md` were incorporated.

## Cross-references

| STAMM file | v4 equivalent | Difference |
|------------|---------------|------------|
| `attack-vectors/pool/*.md` | `attack-vectors/general/*.md` + `attack-vectors/route/*.md` + `attack-vectors/provider/pact.md` | Router vectors split by surface, not by attack type |
| `attack-vectors/admin/*.md` | (covered in `attack-vectors/general/` and `SECURITY.md`) | Router has no separate admin contract |
| `attack-vectors/factory/*.md` | (covered in `attack-vectors/provider/`) | Router has no factory |
| `attack-vectors/registry/*.md` | (covered in `attack-vectors/route/`) | Router has no registry |
| `contracts/cross-contract-interactions.md` | `contracts/cross-contract-interactions.md` | Adapted for router's external pool calls |
| `contracts/state-keys.md` | `contracts/state-keys.md` | Adapted for router's global state |
| `findings/` | `findings/` | Same structure, fewer findings |
| `methodology/scope.md` | `methodology/scope.md` | Same structure, different scope |
| `methodology/audit-coverage.md` | `methodology/audit-coverage.md` | Same structure, different statistics |
| `methodology/glossary.md` | `methodology/glossary.md` | Extended with MWPT terms |
| `scripts/check-leaks.sh` | (not copied) | Router repo has its own linting |
| `IS-STAMM-SAFE.md` | `IS-IT-SAFE.md` | Adapted for router context |
| `REPORT.md` | `REPORT.md` | Same structure |
| `DISCLAIMER.md` | `DISCLAIMER.md` | Same structure |
| `SECURITY.md` | `SECURITY.md` | Adapted for router's trust model |
| `README.md` | `README.md` | Same structure |
