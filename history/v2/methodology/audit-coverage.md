# Audit Coverage

## Evidence summary

| Area | Evidence |
|---|---|
| On-chain source | Complete 2,338-line Python source traced by method and subroutine |
| Compiled artifact | Puya 5.9.0 compile completed after remediation |
| Contract unit guards | 65 focused tests passed |
| Offline router suite | 532 passed, 173 environment-marked tests deselected |
| Engine quote-signing tests | 72 passed |
| Wallet bridge tests/build | 85 TypeScript tests passed; production build succeeded |
| Widget bridge tests | 168 passed |
| Phase 6 manifest tests | 3 passed |
| Brief-supplied full suite | 662 passed, 2 skipped |
| LocalNet behavior | Worktree run: 111 passed after Phase 1 property fuzzing |
| Mainnet execution/simulation | Brief reports 19 execute tests and two real mainnet groups |
| Real provider opcode fuzzing | 16 Hypothesis-supported values on a live mainnet STAMM-containing route |
| Testnet execution | Brief reports 11 tests, one skipped |
| Invariants | 30 documented properties in `router/docs/invariants.md`, each with a four-field mapping |
| Static analysis | Tealer triage supplied; several detectors are vacuous or path-walk limited |

## Coverage by phase

### Phase 1: Architecture and trust

Mapped caller, widget, quote signer, admin, provider, pool and treasury trust
boundaries. The key distinction is that this router is not a self-contained AMM:
external pools are black-box calls and the application temporarily holds user
assets.

### Phase 2: Public methods and state

Traced every public method, every global write and every inner transaction.
Special attention was given to admin-only methods, clear/delete behavior,
`accrued`, temporary opt-ins and the quote-signer state.

### Phase 3: Multi-hop accounting

Reviewed input transaction binding, pre/post balance reads, intermediate
transfers, ALGO fee measurement, route3's extra holding, global output floors,
split route logs and final payout/close behavior.

### Phase 4: External applications and resources

Reviewed Tinyman address derivation, creator/list pinning, STAMM budget calls,
box references, foreign arrays, provider selectors and opcode/group limits.

### Phase 5: Off-chain boundary

Reviewed quote-note construction, group reassembly, route placement, fee
pooling, resource naming, validity windows and whether the final group is
actually signable by the parties expected to submit it.

### Phase 6: Adversarial synthesis

Applied the STAMM 121-vector mindset plus the three independent analyses. The
router-specific additions were MBR griefing, external app spoofing,
cross-protocol state assumptions, malicious pool behavior, funding reuse,
cross-hop floors, quote signing, resource exhaustion and provider upgrade risk.

## Coverage gaps

- No KAVM or symbolic model of bounded route3 execution.
- No executed route with a pre-existing input ASA holding and a pool that leaves
  an input residual.
- No property-based fuzzing of arbitrary foreign-resource permutations or full
  group state transitions; Phase 2 covers route assets, deployment opup counts
  and the contract opup boundary.
- No real-signature integration test through the production API.
- No property-based fuzzing of same-group administrative call combinations.
- No provider program-hash or upgrade-authority verification.
- No independent human review.
