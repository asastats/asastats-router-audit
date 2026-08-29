# Smart Router Security Audit — v4

A comprehensive security audit of the ASA Stats Smart Router smart contract at `<router>/contracts/router_app.py`, focusing on the **Pact MWPT (Managed Weighted Pool)** integration and on the residual attack surface that the prior v3 audit accepted as by-design.

The methodology is adapted from the STAMM AMM Audit at `<audit>/STAMM-AI-AUDIT-main/`, layered with three independent analyses (`analysis1.md`, `analysis2.md`, `analysis3.md`), the v3 audit plan (`algorand-amm-router-audit-plan.md`), and the Trail of Bits Algorand vulnerability-scanner skill (`algorand-vulnerability-scanner/`).

**Verdict:** No new critical or high-severity vulnerabilities introduced by the MWPT integration. All v3 findings remain resolved or are re-affirmed below by design. **Three new findings** (one Medium, two Low) cover MWPT-specific edge cases. **One accepted risk** is refined to reflect the new factory address.

**New here?** Read [Is the Router Safe? v4](IS-IT-SAFE.md) for the plain-English overview.

## What changed since v3

| Change | Source | Audit impact |
|--------|--------|--------------|
| **Pact MWPT pool support** added | `router/venues.py:_pact_mwpt_venues`, `router/curves.py:pact_mwpt_out`, `router/legs.py:pact_mwpt_leg`, `contracts/router_app.py:_pact_leg` selector branch | New provider path; new M1 finding (weight-asymmetry quoting drift); two L-class findings |
| **Mainnet redeployed** as app ID 769636397 (2026-08-21); testnet as 3680942699 | `router/deployments.py` | Provider authentication list extended; deployment audit ledger extended |
| **AlgoFi pool list widened** | `_assert_listed` | I7 (v3) re-evaluated as still accepted by design |
| **`accrued` quota adjusted** | `MIN_CONVERSION_BATCH` template var | H6 (v4, retained from v3) re-evaluated; liveness bound now provably satisfied |
| **STAMM tier-merge leg** | `router/legs.py:stamm_routed_leg` | Refactor; v3 M5 (opups) regression-checked |
| **`RESTRICT_TO_ADMIN`** template var still present (production=0, test=1) | `router_app.py:1930-2063` | v3 I-class: re-evaluated; **flagged for removal** before unrestricted deployment |

## Where to find what

| You want to... | Read |
|----------------|------|
| Quick yes/no on safety, with common questions | [IS-IT-SAFE.md](IS-IT-SAFE.md) |
| The full technical audit report | [REPORT.md](REPORT.md) |
| A specific finding (M1, L1, L2, M-regressions) | [findings/](findings/) |
| How attacks were systematically analyzed | [attack-vectors/](attack-vectors/) |
| Per-component verification deep-dives | [contracts/](contracts/) |
| Audit scope, methodology, glossary | [methodology/](methodology/) |
| Tool results (Tealer, vulnerability-scanner) | [tools/](tools/) |
| Smart contract improvements from this audit | [IMPROVEMENTS.md](IMPROVEMENTS.md) |
| Threat model | [SECURITY.md](SECURITY.md) |
| Limitations of this AI audit | [DISCLAIMER.md](DISCLAIMER.md) |

## Findings at a glance

| Severity | Count | New in v4 |
|----------|-------|-----------|
| Critical | 0 | 0 |
| High     | 0 | 0 |
| Medium   | 1 | M1 (MWPT weight asymmetry quoting drift) |
| Low      | 2 | L1 (MWPT fee skip on zero-output branch), L2 (MWPT vault address is implicit) |
| Informational | 2 | I1 (`RESTRICT_TO_ADMIN` flag still in source), I2 (AlgoFi pool list widening policy) |
| Regressions from v3 | 0 | all v3 findings remain patched or accepted by design |

## Contracts audited

| Contract | File | Lines (TEAL) | Role |
|----------|------|--------------|------|
| Router approval | `router/build/tealer/Router.approval.teal` | ~4,657 | All swap and admin entry points |
| Router clear | `router/build/tealer/Router.clear.teal` | 7 | `pushint 1; return` |
| Stub / harness | `router/contracts/stub_pool.py`, `router/contracts/router_harness.py`, `router/contracts/malicious_pool.py` | n/a | Test surfaces only — out of audit scope |

The audit covers every ABI entry point, every inner-transaction construction, every global-state read/write, and every ARC-4 dynamic-array boundary. Off-chain code (`router/router/*.py`) is in scope for behaviour-equivalence verification only; security claims rest on the on-chain TEAL.

## Repository structure

```
audit/router-audit-v4/
├── README.md              -- This file (audit navigation hub)
├── REPORT.md              -- Full consolidated technical report
├── IS-IT-SAFE.md          -- Plain-English safety overview and FAQ
├── IMPROVEMENTS.md        -- Concrete contract improvements from this audit
├── SECURITY.md            -- Threat model and incident-response runbook
├── DISCLAIMER.md          -- AI-audit limitations and verdict vocabulary
├── LICENSE                -- CC BY-SA 4.0
├── findings/              -- All findings (M1, L1, L2, I1, I2, regression)
├── attack-vectors/        -- Attack vectors in per-component subfolders
│   ├── provider/          -- Tinyman v2, Pact (+ MWPT), STAMM, AlgoFi
│   ├── route/             -- path validation, multi-hop conservation, slippage
│   ├── pact/              -- MWPT-specific (weighted-pool math, vault)
│   └── general/           -- group, MBR, reentrancy-style, gas, deployment
├── contracts/             -- Per-component analysis
│   ├── state-keys.md      -- Global-state key inventory for the router
│   └── cross-contract-interactions.md  -- Router ↔ external pool call graph
├── methodology/           -- Scope, coverage, glossary, plan, plan vs STAMM
└── tools/                 -- Tealer output, vulnerability-scanner output
```

## Audit lineage

This is the fourth AI-led audit of the same contract family. Each prior round patched or accepted the findings from the previous round; v4 inherits the residual accepted-by-design list and adds MWPT-specific findings.

| Audit | Date | Headline result | Repository |
|-------|------|-----------------|------------|
| v1 | 2026-08-11 | C1 (fee drain), H1 (widget floor zero), 10 other findings | `audit/router-audit-v1/` |
| v2 | 2026-08-13 | H1 release-quote-signature, M3 preheld-input-conservation | `audit/router-audit-v2/` |
| v3 | 2026-08-15 | 17 findings synthesised; ToB scanner PASS | `audit/router-audit-v3/` |
| **v4** | **2026-08-22** | **MWPT integration; 5 new findings; no regressions** | `audit/router-audit-v4/` |

License: **CC BY-SA 4.0** ([LICENSE](LICENSE)).
