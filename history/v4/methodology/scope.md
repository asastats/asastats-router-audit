# Scope — v4 Smart Router Audit

## In scope

### On-chain contract
- **File:** `router/contracts/router_app.py`
- **Compiler:** PuyaPy v5.9.0 (Algorand Python → TEAL v11)
- **Source identification:** git revision `5690473` of `<router>/`, working tree clean at audit time
- **Compiled artifact:** `router/build/tealer/Router.approval.teal` (4,657 lines)
- **Approval program:** every ARC-4 entry point, every `@subroutine`, every global-state read/write
- **Clear-state program:** `Router.clear.teal` (7 lines: `pushint 1; return`)

### Off-chain code (behaviour-equivalence verification only)
- `router/router/curves.py` — curve math (`pact_out`, `pact_stableswap_out`, `pact_mwpt_out`, `stamm_*`, `tinyman_v2_*`, `algofi_*`)
- `router/router/venues.py` — pool discovery (`_pact_venues`, `_pact_mwpt_venues`, `_tinyman_v2_venues`, `_stamm_venues`, `_algofi_venues`)
- `router/router/legs.py` — leg construction (`tinyman_v2_leg`, `pact_leg`, `pact_mwpt_leg`, `stamm_leg`, `algofi_leg`)
- `router/router/contract.py` — group assembly, fee computation, route_fee, Leg struct
- `router/router/quote.py`, `allocate.py`, `selection.py`, `build.py`, `simulate.py` — quote composition (audit-relevant when they affect what gets sent to the chain)

### Configuration
- `router/scripts/deploy.py` — deployment script (template variables, route_fee sizing, PACT_POOL_CREATORS, STAMM_POOL_CREATORS, ALGOFI_POOLS, RESTRICT_TO_ADMIN)
- `router/requirements.txt` — pinned dependencies
- `router/SECURITY.md`, `router/README.md`, `router/docs/invariants.md` — documentation

### Deployments
- Mainnet app ID **769636397** (2026-08-21)
- Testnet app ID **3680942699** (2026-08-21)

### Tests
- `router/tests/test_router_contract.py` — focused contract guard tests
- `router/tests/test_pact_mwpt.py` — MWPT-specific tests
- `router/tests/test_curves.py` — curve math tests
- `router/tests/test_contract_localnet.py` — LocalNet integration tests
- `router/tests/test_curves_against_chain.py` — mainnet-state curve verification
- `router/tests/test_stamm_opups.py` — STAMM opup sizing

## Out of scope

### External pool contracts
- Tinyman v2 pool contract (referenced via LogicSig hash; not audited)
- Pact constant-product, stableswap, and MWPT pool contracts (referenced via creator pin; not audited)
- STAMM pool contract (referenced via creator pin; STAMM was audited separately at `<audit>/STAMM-AI-AUDIT-main/`)
- AlgoFi pool contracts (referenced via whitelist; not audited)

### Off-chain infrastructure
- Frontend (`<workspace>/frontend/`) — wallet UI, route selection UI
- Engine (`<workspace>/engine/`) — Django backend, monitoring daemon
- Quote server — backend that signs floors (security model assumes the quote signer is a separate, hardened service)
- Voucher server — backend that signs fee discount vouchers

### Bytecode-vs-source
- The compiled TEAL at `router/build/tealer/Router.approval.teal` is assumed to match the audited source. The audit does **not** perform a fresh diff; the deployment script verifies this at deploy time.

### Compiler security
- The Puya compiler itself (v5.9.0) is assumed secure per its security bulletin history. The audit notes that older compiler versions lack automatic ARC-4 dynamic-array length validation.

### Economics / governance outside the router
- ASA Stats tokenomics (`ASASTATS` token contract)
- Staking / rewards
- Admin key custody (recommended hardware/multisig in SECURITY.md)

## Methodology limitations

1. **AI-only review.** This audit was conducted by an AI multi-agent system. It is not a replacement for human expert review by an Algorand-experienced auditor.
2. **Static + dynamic.** The audit combines static (Tealer, source review, Trail of Bits checklist) and dynamic (test suite, LocalNet, mainnet) verification. It does not include formal verification (KAVM, Lean).
3. **Off-chain ↔ on-chain divergence.** The audit verifies that off-chain quoters match on-chain behaviour for the MWPT path. A residual 1-microunit drift is documented in finding M1.
4. **External pool integrity.** The audit verifies the router's interaction with external pools, not the pools' internal soundness.

## Source identification

| Item | Identifier |
|------|------------|
| Router source | git revision `5690473` |
| Audit date | 2026-08-22 |
| Audit framework | Multi-agent AI system (Claude) |
| Mainnet app ID | 769636397 |
| Testnet app ID | 3680942699 |
| Compiler | puyapy 5.9.0 |

## Re-audit triggers

This audit should be re-run when:

1. **Any change to** `router/contracts/router_app.py`, `router/router/curves.py`, `router/router/legs.py`, or `router/router/venues.py`.
2. **Compiler upgrade** to a new major version (e.g., puyapy 6.x).
3. **Pact factory migration** (the MWPT factory creator address changes).
4. **New provider** added (e.g., a new AMM beyond Tinyman v2 / Pact / STAMM / AlgoFi).
5. **New pool type** added (e.g., a new MWPT variant).
6. **New admin mechanism** added (e.g., multisig, timelock).
7. **New fee mechanism** added (e.g., a second protocol fee).
