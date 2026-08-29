# Audit Plan — Smart Router

The goal is to produce a repository at `@audit/router` that contains all the data a human auditor (and the development team) needs to trust the smart router, and to improve the contract based on the audit outcome.

## 1. Preparation (1–2 days)

- [x] Read the STAMM audit repository and extract its structure and vector taxonomy.
- [x] Read the three independent analyses and identify overlaps and gaps.
- [x] Read the router threat model (`router/SECURITY.md`) and the router source.
- [x] Confirm the language/compiler stack (Puya / Algorand Python, TEAL output, `algopy_testing`).
- [ ] Pin exact compiler versions and record them in `methodology/sources.md`.
- [ ] Compile the contract once and record the approval/clear program hashes.

## 2. Source Inventory & Traceability (2–3 days)

- [ ] List every externally callable method, its ARC-4 selector, and its trust assumptions.
- [ ] Map every inner transaction (`itxn`) to the method that emits it.
- [ ] Trace every global-state read/write.
- [ ] Identify every `TemplateVar` and what deployment values substitute for it.
- [ ] Document the relationship between off-chain `router.contract` and on-chain ABI.

## 3. Attack-Vector Matrix (3–4 days)

Build a router-specific matrix modelled on STAMM's 121 vectors. Target at least 80 vectors grouped into:

| Category | Focus |
|----------|-------|
| Access control | Admin, keeper, voucher signer, restrict flag |
| Group transactions | Rekey/close, padding, ordering, fee pooling, duplicate txns |
| Inner transactions | Fee=0 enforcement, resource arrays, cross-app call safety |
| Arithmetic | Fee skim, slippage, rounding, overflow/underflow, multi-hop precision |
| Economic | MEV/sandwich (Algorand-specific), donation attacks, fee evasion |
| Provider spoofing | Tinyman derivation, Pact/STAMM/AlgoFi app ID authenticity |
| Resource limits | Opcode budget, group size, 8-reference ceiling, MBR |
| Route correctness | Cycles, duplicate assets, multi-hop slippage drift, atomicity |
| Conversion / treasury | `convert_and_distribute` trust boundary, batch bounds |
| ARC-4 / ABI | Encoding validation, selector routing, typed txn references |

Each vector resolves to one of: **Defended**, **Mitigated**, **Not applicable**, **Admin-controlled**, **Accepted**, or **Open finding**.

## 4. Deep-Dive Testing (3–5 days)

- [ ] **Fuzzing**: add Hypothesis-based fuzz tests for transaction-group structure, asset flows, and slippage invariants.
- [ ] **Malicious-pool harness**: deploy stub pools that return wrong amounts, revert, or steal funds; run router against them.
- [ ] **Differential testing**: compare outputs against Folks / Pact / Deflex where possible.
- [ ] **Opcode budget measurement**: instrument the deployed contract to log remaining budget for the widest realistic routes.
- [ ] **Reference-count adversarial tests**: ensure no four-leg route can be built, and that three-leg routes never exceed eight references.

## 5. Formal / Semi-Formal Invariants (2–3 days)

Write down the key multi-hop invariants:

1. **Funds conservation**: input = output + fees + dust ≥ 0.
2. **Router balance neutrality**: non-fee asset balances are unchanged by a route.
3. **Slippage**: final output ≥ `minimum_received`.
4. **No cycles**: route assets are distinct except where explicitly allowed.
5. **Pool authenticity**: only approved/factory-derived pools are called.
6. **Deadline**: a group executed after its deadline reverts.

Evaluate which can be encoded as runtime asserts and which need KAVM / theorem-prover treatment.

## 6. Findings & Report (2–3 days)

- [ ] Draft findings with severity, location, PoC, impact, and recommendation.
- [ ] Produce `REPORT.md` with executive summary, methodology, findings, and roadmap.
- [ ] Produce `IS-IT-SAFE.md` for non-technical stakeholders.
- [ ] File follow-up issues for items that cannot be fixed in source without an ABI break.

## 7. Contract Improvements & Verification (3–5 days)

- [ ] Implement agreed source-level mitigations.
- [ ] Update off-chain builders and tests to match ABI changes.
- [ ] Run `pytest -m 'not mainnet' -m 'not testnet'` for fast feedback.
- [ ] Run LocalNet tests if a node is available.
- [ ] Run mainnet simulation smoke tests for the patched paths.

## 8. Hand-Off (1 day)

- [ ] Record compiler hashes and deployed program hashes.
- [ ] Update `router/SECURITY.md` and `router/README.md` with audit conclusions.
- [ ] Provide a clear go/no-go recommendation for lifting `RESTRICT_TO_ADMIN`.

## Recommended external review

Engage an Algorand-experienced human auditor (e.g. Runtime Verification, Vantage Point, or a comparable firm) for:

- Manual review of the routing-path invariants.
- KAVM or equivalent verification of the multi-hop conservation claims.
- Review of the signed-floor design before implementation.
