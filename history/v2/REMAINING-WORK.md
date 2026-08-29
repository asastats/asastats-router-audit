# Remaining Work After Phase 6 Tooling

This document records what remains from points 1-5 of
`REMEDIATION-AND-RELEASE-PLAN.md` and from
`PHASE-5-QUOTE-SIGNER-PLAN.md`.

Statuses distinguish implementation from runtime evidence. A test or source
change in the worktree does not prove that the same behavior has been deployed
to testnet or mainnet.

## Phase 1: Adversarial Pool Tests

**Status:** deterministic and property-based LocalNet coverage complete.

Implemented:

- Approved-creator malicious pool fixture.
- Test-only router harness for persistent input opt-ins.
- Wrong output asset.
- No output.
- Wrong recipient.
- Output below the signed floor.
- Residual input in a pre-held router balance.
- Extra provider output measured from the router balance delta.
- Provider-owned inner fees do not spend the router float.
- Atomic balance and state rollback checks.
- Hypothesis coverage across all malicious modes, route amounts and floors.

Remaining:

- No separate adversarial tests against every real provider implementation.
- No mainnet or testnet execution using a malicious pool, which is intentionally
  limited to LocalNet.
- Outer-group close/rekey behavior is covered by existing router hygiene tests,
  not by a malicious pool fixture. This is appropriate because an external pool
  cannot rekey the router account.

## Phase 2: Bounded Opcode Fuzzing

**Status:** core boundary implementation and deterministic tests complete.

Implemented:

- `MAX_STAMM_OPUPS = 8` in the contract and builder.
- Contract rejection above the maximum.
- Builder rejection of an overlarge deployment configuration.
- Hypothesis coverage for route asset sanitization and the full `uint64` opup
  range.
- Hypothesis coverage for generated group sizes, prefixes, provider resource
  shapes and unknown providers.
- LocalNet tests for the accepted maximum and maximum plus one.
- Strict mainnet STAMM opup measurement suite passing with routed floor 7 and
  deployed count 8.
- Strict mainnet Hypothesis simulation of a live STAMM-containing router route
  across supported opup values.

Remaining:

- No equivalent real-provider fuzzing for every provider combination or a
  target-network STAMM deployment other than the current mainnet route.
- No automated remeasurement and manifest update when a STAMM pool or provider
  deployment changes.
- The maximum remains a single measured deployment-wide value rather than a
  pool/tier lookup.

## Phase 3: Real Pre-Held-Input LocalNet Test

**Status:** complete.

Implemented:

- Test-only `RouterHarness.seed_holding(asset)` setup method.
- Correct held-input group shape without a temporary opt-in.
- Route-call index and signed-floor binding for the shorter held-input group.
- Successful cooperative-pool control preserving the existing input balance.
- Malicious approved-creator pool rejection when input remains after leg one.

No Phase 3 implementation remains. Production does not receive the harness
method.

## Phase 4: Same-Group Conversion Approval

**Status:** complete.

Implemented:

- `SET_CONVERSION_POOL_SIGNATURE` pinning.
- `_assert_no_conversion_pool_approval` scan.
- Rejection of any conversion group containing `set_conversion_pool`.
- LocalNet rollback test for attempted same-group approval and conversion.
- Separate-group conversion positive control.

No Phase 4 implementation remains. The guard protects against administrative
construction mistakes, not a stolen admin key.

## Phase 5: Quote-Signer Co-Signing

**Status:** backend and wallet-source implementation complete; runtime release
verification remains.

Implemented:

- `engine/core/quote_signer.py`.
- Network-specific mnemonic loading.
- Group/other permission rejection for signer files.
- On-chain signer-address verification.
- Quote authorization validation and signing after group assembly.
- Configurable 120-round default validity window.
- API response fields for signed quote transactions and validity rounds.
- Wallet bridge support for pre-signed group members.
- Wallet-side group/index/signature validation.
- ASA Stats widget handling for partial signed groups.
- Pera-compatible explicit signing-index flow in the wallet bridge.
- Engine tests, wallet TypeScript tests and widget JavaScript tests.
- Testnet-specific Tinyman topology and live liquidity snapshot generation.
- Engine testnet algod/provider selection and dump-preferred liquidity loading.
- Production engine quote and group build against testnet app `769208655`.
- Strict simulation of the production-built testnet group with the backend
  quote signature present.
- Automated engine-to-Testnet submission with two normal account signatures.
  Confirmed in round `66278927`; router application-call txids were
  `NDIIENTZVTZGQV3JLCB2BD63KCYLH6G7GPPWXVJGOIDGN6YCKXZQ` and
  `DRPUY35OMBFFJEXJ5ZTDAA6PIAC2F4KJ2NLNPSMTJXTPFQFBCBUQ`.

Remaining:

- Pera mobile runtime compatibility has not been tested.
- Defly mobile runtime compatibility has not been tested.
- Other supported wallet runtime compatibility has not been tested.
- Cancellation, delayed signing and expired validity-window behavior have not
  been tested through mobile wallets.
- The production engine testnet quote/build/simulation flow now passes manually;
  it still lacks an automated integration test that drives the complete API.
- No end-to-end LocalNet test currently drives the engine API, backend signer,
  wallet-signature merge and normal-signature submission as one flow.
- The generated testnet topology and liquidity snapshot must be refreshed before
  each target-network exercise.
- The current mainnet deployment remains restricted and has not been replaced
  with a fresh unrestricted deployment carrying the final code.
- The generated wallet bundle must be promoted through the normal frontend
  deployment process and verified in the target environment.
- The Phase 5 test service must explicitly set `ROUTER_NETWORK=testnet` and
  `ROUTER_LIQUIDITY_DUMP` to the generated testnet snapshot.

The successful Testnet submission test is opt-in and must be run with the
explicit environment configuration documented in
`engine/core/tests/test_router_testnet.py`; it is intentionally excluded from
the default suite because it spends Testnet funds.

## Phase 5 Release Prerequisites

Before an unrestricted release, the following must be completed:

1. Verify Pera, Defly and other supported wallets preserve the backend-signed
   quote transaction.
2. Submit a real routed testnet group through the engine API.
3. Test cancellation, delay and expiry with the configured validity window.
4. Verify the signer address and key configuration in the target environment.
5. Deploy and verify the final bytecode through Phase 6 tooling.
6. Obtain human Algorand security review.

## Phase 6: Deployment and Bytecode Verification

**Status:** tooling complete; deployed-application verification pending.

Implemented:

- Puya pinned to `5.9.0`.
- `scripts/deploy.py` release-manifest generation.
- Manifest fields for source, compiler, templates, restriction, schema, pages
  and TEAL/bytecode hashes.
- Independent `scripts/verify_deployment.py` recompilation and on-chain bytecode
  comparison.
- Manifest and verifier unit tests.
- `DEPLOYMENT-VERIFICATION.md` runbook.

Remaining:

- No fresh restricted canary has been deployed with a Phase 6 manifest.
- No deployed application has been verified with `verify_deployment.py`.
- No behavioral restricted-vs-unrestricted canary comparison has been run.
- No fresh unrestricted application exists; `MAINNET.restricted` remains true.
- Testnet Tinyman v2 routing has been exercised against the final unrestricted
  artifact, but conversion has not yet been executed. Pact, STAMM and AlgoFi
  are explicitly N/A for the current Testnet topology.
- Production monitoring code is implemented in `engine/core/monitoring.py` with
  durable models, migrations, a management-command worker and signed webhook
  delivery. It is not activated until the production database, endpoints,
  webhook receiver and on-call ownership are configured.

## Target-Network Exercise and Monitoring

The implementation plan is documented in
`POST-DEPLOYMENT-OPERATIONS-PLAN.md`. It covers:

- Tinyman v2, Pact, STAMM, AlgoFi and route3 provider matrices.
- Normal fee conversion and below-floor final sweep.
- Admin-method alerts.
- Accrual anomaly correlation.
- Float and holding alerts.
- Provider leg-count and zero-liquidity alerts.

Offline preparation is now implemented by
`router/scripts/prepare_target_matrix.py` and has been generated from the
current Redis cache with the dump hash recorded:

- `router/build/target-network/provider-matrix.json`
- `router/build/target-network/provider-matrix.csv`
- `router/build/target-network/conversion-candidates.json`
- `router/build/target-network/monitoring-baseline.json`

The current Testnet snapshot is also recorded under
`router/build/target-network-testnet/`. It covers all 7 graph pairs, identifies
Tinyman v2 as the only available provider, records Pact/STAMM/AlgoFi as N/A,
and uses Testnet fee asset `450822081` for the conversion candidate.

Fixture-driven monitoring parsing and alert policy are implemented by
`router/scripts/monitor_router.py` and covered by
`router/tests/test_monitor_router.py`. This is not a production polling worker
or alert destination by itself. The production deployment runbook is
`MONITORING-DEPLOYMENT.md`.

Regenerate these artifacts immediately before target-network use:

```bash
python scripts/prepare_target_matrix.py --network mainnet --all-pairs
```

The data does not establish live reserves, fees, creator/update authority,
quote output, conversion output or target-network transaction success.

These are operational plans only. They require a fresh verified deployment,
target-network access, funded canary accounts and operator ownership.

## Operational Work Not Yet Completed

The following remain untouched or require target-network access:

- Continuous monitoring and alerting.
- Bug bounty.
- Formal KAVM or SMT verification.
- Provider approval-program hash and upgrade-authority monitoring.
- Full differential testing against other routers.
