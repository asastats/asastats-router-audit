# Audit Scope

## In Scope

### On-chain router application

- `router/contracts/router_app.py` — the complete ARC-4 router application
- All externally callable methods:
  - `route`
  - `route3`
  - `opt_in_asset`
  - `verify_discount`
  - `pool_budget`
  - `set_admin`
  - `set_escrow`
  - `set_fee`
  - `set_voucher_signer`
  - `close_holding`
  - `convert_and_distribute`
  - `delete_application`
- All internal subroutines and state keys
- Template variables and how they constrain deployment trust
- Clear-state program behaviour (inherited from `ARC4Contract`)

### Off-chain router code

- `router/router/contract.py` — route-to-group translation, resource accounting
- `router/router/legs.py` — per-provider leg construction
- `router/router/build.py` — group assembly and logic-signature mapping
- `router/router/quote.py` — quote invariants and `realised_outputs`
- `router/router/voucher.py` — discount voucher signing
- `router/router/venues.py` — venue discovery and route collapsing
- `router/router/allocate.py` — split allocation
- `router/SECURITY.md` — threat model review
- `router/router/deployments.py` — deployment metadata

### Test suite

- `router/tests/test_router_contract.py` — unit-level guard tests
- `router/tests/test_contract_localnet.py` — LocalNet integration
- `router/tests/test_contract_testnet.py` — testnet smoke tests
- `router/tests/test_execute.py` and provider-specific execution tests

## Out of Scope

- Stages 0–3 of the router (off-chain quote construction and group assembly without the application)
- The liquidity engine and `al:*` cache
- The ASA Stats frontend / widget, except where it feeds data to the contract
- STAMM pool math correctness (already covered by the separate STAMM audit)
- Economic modelling, MEV profitability, or formal verification of the STAMM protocol
- Deployment key management and operational security of the admin/keeper keys

## Audited Source Identification

| Component | File | Type |
|-----------|------|------|
| Router application | `router/contracts/router_app.py` | Puya / Algorand Python source |
| Off-chain translator | `router/router/contract.py` | Python source |
| Group builder | `router/router/legs.py`, `router/router/build.py` | Python source |
| Quoting invariants | `router/router/quote.py` | Python source |
| Threat model | `router/SECURITY.md` | Markdown |

## Methodology

1. **Architecture review** — read threat model, README, SECURITY, and key source files.
2. **STAMM audit mapping** — adapt the 121-vector matrix from the STAMM audit to router/aggregator semantics.
3. **Independent-analysis synthesis** — integrate the three provided analyses and identify gaps.
4. **Manual code review** — trace every public method and critical subroutine.
5. **Test-suite analysis** — identify what is covered and what is missing.
6. **Attack-vector enumeration** — produce per-category vectors in `attack-vectors/`.
7. **Finding triage** — classify by severity and exploitability.
8. **Mitigation** — apply source-level fixes where feasible, document proposed fixes otherwise.
9. **Verification** — run the offline test suite and any LocalNet tests that can be executed.

## Limitations

- This audit was conducted by an AI system. It is systematic but should be complemented by a human Algorand security expert before mainnet unrestricted deployment.
- No formal proofs were generated. Arithmetic invariants are stated semi-formally.
- Some findings depend on mainnet behaviour that can only be validated by simulation or testnet execution.
