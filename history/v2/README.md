# Smart Router Security Audit v2

This repository records the second security review of the Algorand smart
router. It uses the STAMM audit repository as a methodology reference, but
adapts the threat model to an aggregator that calls external AMMs and holds a
caller's assets between inner transactions.

**Review subject:** `router/contracts/router_app.py`, identified by the v2
brief as commit `932ebfb`.

**Primary question:** may `RESTRICT_TO_ADMIN` be lifted?

**Verdict:** no direct public-caller theft path was confirmed after the v1
changes, assuming the pinned provider deployers and quote signer are trusted.
The restriction should nevertheless remain until the release signing path is
fixed, the patched contract is deployed and exercised, and an
Algorand-experienced human reviews this audit. This work is AI-assisted and is
not a substitute for that review.

## Navigation

| Need | Read |
|---|---|
| Plain-language verdict | [IS-IT-SAFE.md](IS-IT-SAFE.md) |
| Technical report and findings | [REPORT.md](REPORT.md) |
| Scope and limitations | [methodology/scope.md](methodology/scope.md) |
| Coverage and evidence | [methodology/audit-coverage.md](methodology/audit-coverage.md) |
| Synthesis of STAMM analyses | [methodology/independent-analyses.md](methodology/independent-analyses.md) |
| Attack-vector matrix | [attack-vectors/README.md](attack-vectors/README.md) |
| On-chain method review | [contracts/router_app.md](contracts/router_app.md) |
| Individual findings | [findings/](findings/) |

## Findings at a glance

| ID | Severity | Status |
|---|---|---|
| H1 | High availability | Patched in the worktree: backend signs; mobile-wallet verification remains |
| M1 | Medium treasury safety | Patched in the worktree: zero-floor final sweeps are dust-only |
| M2 | Medium accounting | Patched in the worktree: funding must immediately precede the route |
| M3 | Medium accounting | Patched in the worktree: ASA input consumption is asserted |
| M4 | Medium trust boundary | Accepted conditionally: creator pinning is not code-hash authentication |
| M5 | Low availability | Patched in the worktree: STAMM `opups` capped and fuzzed |
| M6 | Low treasury operations | Patched in the worktree: approval and conversion require separate groups |
| I1 | Informational | Quote authorisation transaction type was not previously pinned; patched |

The v1 findings remain patched or accepted as described in
`audit/router-audit-v1/REPORT.md`. This v2 review does not treat a prior
finding status as evidence; each important property was traced to source and
tests again.

## Verification performed

- `python -m pytest tests/test_router_contract.py -q`: 65 passed.
- `python -m pytest tests/test_contract_localnet.py -q`: 111 passed, including Phase 1 property fuzzing.
- `python -m pytest -q -m 'not mainnet and not localnet and not testnet'`: 532 passed, 173 deselected.
- `python -m pytest tests/test_stamm_opups.py -q`: 6 passed against strict mainnet simulation.
- Puya 5.9.0 compiled the updated contract successfully.
- The final local approval artifact after Phase 4 was 4,707 TEAL lines with
  SHA256 `5d384e34a4e7edd7ae9ac3f9b4c83f62cb8c576efb016b0a1154c049da06df2a`.
- The v2 brief reports 662 passed and 2 skipped across its full evidence suite,
  including LocalNet, testnet, simulation and benchmark runs.

The mainnet and testnet evidence is environment- and state-dependent. It is
not repeated by the offline commands above.
