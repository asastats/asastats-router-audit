# Implementation Blockers and Immediate Work

This document records what blocks the remaining work in remediation phases 1-6,
which work can proceed offline, and which work requires target-network, wallet
or operational access.

## Phase 1: Adversarial Pool Tests

### Property-based fuzzing of malicious-pool behavior

**Implemented.**

The deterministic malicious pool already exists. It can be extended with
Hypothesis-generated modes and inputs:

- Output amounts.
- Residual input amounts.
- Wrong asset combinations.
- Zero output.
- Extra output.
- Different route shapes.
- Different group sizes.

The LocalNet property test generates seven malicious modes, variable route
amounts and signed floors. It fuzzes the malicious fixture, not arbitrary real
protocol code.

### Adversarial tests against every real provider

**Blocked by provider ownership and safety boundaries.**

We cannot deploy malicious Pact, STAMM, Tinyman or AlgoFi contracts on their
real networks and still pass the router's provider authentication:

- Pact/STAMM require approved creators.
- AlgoFi requires one of the curated application IDs.
- Tinyman v2 pool addresses are derived and cannot be replaced with an arbitrary
  account.

Possible substitutes are:

- Strict simulation against real provider pools.
- Malformed groups against real pools.
- Provider-specific failure behavior.
- Wrong resource references.
- Stale or drained pools.

A deliberately malicious real provider implementation would require a
provider-approved test deployment or a separate test network.

### Mainnet/testnet execution using a malicious pool

**Intentionally not appropriate.**

A malicious pool deployed by us would normally be rejected by creator/app
authentication. Removing that protection for testing would invalidate the test.

The correct substitutes are a LocalNet malicious pool, strict simulation against
real pools, or a provider-approved testnet fixture.

### Close/rekey behavior

**Already covered.**

This belongs to the existing router hygiene tests, not the malicious pool. An
external pool cannot rekey the router account; the relevant threat is a
malicious outer group signed by the user.

## Phase 2: Bounded Opcode Fuzzing

### Arbitrary foreign-resource permutations and malformed groups

**Implemented offline.**

This can be implemented locally with Hypothesis and LocalNet:

- Missing applications.
- Missing assets.
- Missing STAMM boxes.
- Wrong pool accounts.
- Duplicated resources.
- Non-adjacent funding transactions.
- Extra transactions.
- Multiple authorizations.
- Incorrect route indexes.

`tests/test_fuzz_resources.py` now generates group sizes, prefixes, provider
resource shapes and unknown providers. The properties assert that oversized
groups fail before signing, unknown providers exceed the reference ceiling and
known resource lists remain unique and complete. This is offline construction
coverage; it does not prove live resource availability.

### Property-based fuzzing against real provider opcode consumption

**Implemented for the current mainnet STAMM route; broader coverage remains.**

`tests/test_real_opcode_fuzz.py` uses the current restricted mainnet deployment,
the deployment admin as the simulated caller and a live STAMM-containing route.
It varies supported STAMM opup values with Hypothesis and uses strict
`allow_unnamed_resources=False` simulation without submitting transactions.

Broader real-provider fuzzing requires:

- Mainnet or testnet algod access.
- Current pool application IDs.
- Current pool state.
- Strict simulation with unnamed resources disabled.
- Rate limiting and bounded test volume.

This remains feasible without private keys because simulation does not submit
transactions, but it requires bounded target-network access and rate limiting.

### Automatic STAMM remeasurement and manifest update

**Requires live provider state and operational scheduling.**

Exact STAMM opcode requirements depend on current pool reserves, routing state,
application behavior and inner-call execution.

A scheduler would need to:

1. Discover current STAMM pools.
2. Select representative pool, tier and input cases.
3. Simulate them against algod.
4. Record the worst routed requirement.
5. Reject increases above an approval threshold.
6. Update the release manifest only after review.

### Pool/tier-specific opup lookup

**No external blocker, but it is a design extension.**

It requires a stable pool/tier key, measured opcode data, a cache freshness
policy, a fallback for missing measurements and changes to the builder's fee
model. The current deployment-wide maximum remains simpler and safer.

## Phase 3: Real Pre-Held-Input LocalNet Test

**Complete.**

No remaining implementation blocker exists for Phase 3.

## Phase 4: Same-Group Conversion Approval

**Complete.**

The on-chain guard and rollback test are implemented.

## Phase 5: Quote-Signer Co-Signing

### Real testnet group through the production API

**Implemented with two normal account signatures; wallet runtime remains.**

Required:

- Testnet application carrying the final contract bytecode.
- `quote_signer` configured on that application.
- `conversion_pool` configured if conversion is tested.
- Engine configured for testnet.
- Signer mnemonic available to the engine.
- Funded user wallet.
- Live provider liquidity.
- Normal signature validation.

`engine/core/tests/test_router_testnet.py` now executes this flow against
testnet application `769208655`: the engine builds the group, the backend
signs the quote transaction, the deployer signs user transactions, and the
complete group is submitted and confirmed.

### Pera mobile runtime compatibility

**Requires a real device, wallet app and session.**

Unit tests prove the bridge passes the full group and signer indexes. They do
not prove that Pera preserves the pre-signed quote transaction, skips the quote
index, preserves group order or submits the merged group.

### Defly and other wallet compatibility

**Requires wallet-specific runtime testing.**

Each wallet may differ in handling skipped signer indexes, pre-signed blobs,
partial groups, transaction ordering, deep links and cancellation.

### Cancellation, delay and expiry

**Partly implementable locally; real timing requires devices.**

Local tests can simulate an expired `last_valid`, missing signatures and rejected
wallet promises. Actual delay behavior requires leaving a mobile-wallet prompt
open until the validity window expires.

### Production API integration with a real route

**Requires a complete engine environment.**

Required:

- Django API configuration.
- Redis/cache or controlled fixture data.
- Provider readers.
- Algod access.
- Quote signer key.
- Real routed group assembly.
- Normal transaction serialization.

### Engine-driven LocalNet end-to-end test

**No fundamental technical blocker.**

This can be implemented locally with a LocalNet router, two generated accounts,
a test signer mnemonic, a controlled quote/group response and normal signed
transaction submission.

### Fresh unrestricted mainnet deployment

**Operational and governance blocker.**

Required:

- Human Algorand review.
- Release manifest.
- Verified bytecode.
- Restricted canary.
- Provider and conversion exercise.
- Wallet testnet evidence.
- Deployment authority and funding.
- Fresh application ID.

The existing application cannot be changed from restricted to unrestricted
because `RESTRICT_TO_ADMIN` is compile-time.

## Phase 6: Deployment and Bytecode Verification

### Fresh restricted canary

**Requires deployment authority and target-network funds.**

The scripts are ready, but deployment requires a deployer mnemonic, algod
access/token, funding ALGO, an approved deployment decision and a release source
revision.

### Verifying a deployed application

**Blocked until a new application exists.**

`verify_deployment.py` can verify approval/clear bytecode, TEAL hashes, schema,
extra pages, creator, templates, restriction, quote signer, conversion pool and
fee state. It cannot verify an application that has not been deployed.

### Restricted versus unrestricted behavior comparison

**Requires two target-network deployments.**

The behavioral check needs a restricted application, an otherwise identical
unrestricted application, a funded non-admin account, a valid backend-signed
group and live provider resources.

### Target-network provider and conversion exercise

**Requires live network access and liquidity.**

The offline matrix is prepared, but live execution still needs current reserves,
provider application state, creator/update-authority verification, funded canary
accounts, wallet or signing-service submission and monitoring.

### Monitoring worker and alert delivery

**Requires operational infrastructure and ownership.**

The monitoring design can be implemented locally against fixtures, but production
activation requires a polling worker, algod/indexer credentials, durable metric
storage, alert destinations, on-call ownership and an incident runbook.

## Work That Can Proceed Immediately

The following require no target-network deployment:

1. Hypothesis fuzzing of arbitrary malformed resource and group combinations.
2. A complete engine-to-LocalNet two-key signing test.
3. Negative tests for expired and mutated partial groups.
4. Offline provider-matrix validation against `data/amm`.
5. Monitoring parsers and alert logic using saved transaction/state fixtures.
6. Release-manifest tamper tests.
7. Behavioral verifier tests using controlled application metadata.
8. Provider-matrix consistency checks against deployment pins and the AlgoFi
   list.

The following require target-network access:

1. Real provider opcode fuzzing.
2. Real testnet backend/wallet submission.
3. Pera and Defly mobile testing.
4. Conversion execution.
5. Restricted/unrestricted canary comparison.
6. Production monitoring activation.
7. Final unrestricted deployment.
