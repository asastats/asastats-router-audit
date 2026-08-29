# Audit Scope

## In scope

### On-chain application

- Complete `router/contracts/router_app.py` and its clear-state behavior.
- ARC-4 methods: routing, route3, opt-in, quote discount, budget, admin,
  escrow, fee, signer rotation, conversion, holding closure and deletion.
- All internal subroutines, global state, template values and inner
  transactions.
- Asset/ALGO accounting, route floors, group hygiene, provider dispatch,
  opcode budgets and resource references.

### Off-chain execution boundary

- `router/router/contract.py`: ABI, transaction references, fee sizing and
  quote-note construction.
- `router/router/build.py` and `router/router/legs.py`: group assembly,
  route ordering, quote authorisation placement and provider leg construction.
- `router/router/quote.py`: route floor and shared-pool realized output model.
- `engine/core/router.py` and the wallet-facing group serialization boundary,
  because the v2 question is an unrestricted deployment decision.
- `router/SECURITY.md`, deployment metadata and relevant tests.

### Research inputs

- `audit/STAMM-AI-AUDIT-main` as the systematic attack-vector and invariant
  reference.
- `audit/analysis1.md`, `analysis2.md` and `analysis3.md` as independent
  reviews of aggregator-specific and Algorand-specific gaps.
- `audit/router-audit-v1` as the prior findings and remediation record.

## Out of scope

- Correctness or security of Tinyman, Pact, STAMM and AlgoFi implementations as
  independent protocols, except at their router interfaces.
- The liquidity engine's data freshness and route-selection economics beyond
  the boundary where they determine a signed floor.
- Formal KAVM, SMT, Lean or theorem-prover verification.
- Private-key custody, backend host security and operational access controls,
  except for the fact that the production path must obtain a quote signature.
- Mainnet traffic, pool upgrade history and bug-bounty response beyond evidence
  supplied in the v2 brief.

## Source identification

The brief identifies the review target as `router/contracts/router_app.py` at
`932ebfb` and the unrestricted superset build as the analyzed program. The
worktree has no usable Git history, so bytecode identity must be verified from
the deployment compiler output rather than inferred from repository history.
After Phase 4 remediation, Puya 5.9.0 generated a 4,707-line approval TEAL file before
network template substitution. The resulting local approval artifact had SHA256
`5d384e34a4e7edd7ae9ac3f9b4c83f62cb8c576efb016b0a1154c049da06df2a`.

## Limitations

- This is an AI-assisted audit. No Algorand-experienced human review is present
  in this repository.
- The most important cross-protocol assumptions require target-network
  simulation or execution.
- LocalNet stubs cannot prove that real provider programs accept every inner
  transaction shape.
- Empty-signature simulation cannot prove production signing or custody.
- No property-based fuzzing of real provider code or formal model was completed
  in this pass; deterministic and fixture-based malicious-pool LocalNet
  coverage is present.
