# Remediation and Unrestricted Release Plan

This document describes how to resolve the remaining audit recommendations and
how to safely move from the restricted router deployment to an unrestricted
deployment.

## 1. Adversarial Pool Tests

**Status:** implemented in Phase 1. The LocalNet suite now contains an
approved-creator malicious pool and a test-only router harness. Seven tests
cover wrong output, no output, wrong recipient, low output, residual input in
a pre-held balance, extra output and provider-owned inner fees.
Hypothesis additionally generates 40 combinations of those behaviors, route
amounts and signed floors.

The existing `contracts/stub_pool.py` remains cooperative except for
deliberately misreporting its output. The adversarial coverage uses the
separate `contracts/malicious_pool.py` fixture rather than weakening the
existing behavioral stub.

Coverage matrix:

| Behavior | Expected result |
|---|---|
| Returns less output than its log claims | Route fails the signed floor |
| Returns output but leaves some input ASA in the router | Route fails `_assert_input_spent` |
| Pays output in the wrong asset | Route fails or output delta remains zero |
| Sends output to the wrong account | Route fails because the router's balance does not increase |
| Charges an inner transaction fee | Provider pays its own fee; router float remains unchanged |
| Sends an unexpected close/rekey transaction | Group is rejected by hygiene checks |
| Returns zero output | Route fails unless a zero floor was issued, which should not happen for normal trades |
| Sends extra output/donation | Only the router's measured delta is forwarded |

The malicious pool must pass the current provider boundary. In LocalNet, deploy
it from the same creator account used in the Pact/STAMM template values. An
impostor deployed by a different account only tests provider authentication and
will be rejected before the malicious behavior executes.

Recommended test structure:

1. Deploy a malicious stub from an approved LocalNet creator.
2. Stock it with the required assets.
3. Execute a route with a valid quote-signer authorization.
4. Snapshot caller balances, router balances, router holdings and `accrued`.
5. Assert that the group is rejected.
6. Assert that every snapshot is unchanged after rejection.

The most valuable new test is:

```text
router already opted into asset_in
malicious first pool returns output but leaves input behind
route must reject atomically
```

This is exercised by
`TestAdversarialPools::test_a_pool_leaving_input_in_a_preheld_router_balance_is_rejected`.

The table's close/rekey case remains covered by the router's existing
`TestGroupHygiene` tests rather than by the pool fixture. An external pool
cannot rekey or spend the router account; its own inner transaction fee is
covered separately by
`TestAdversarialPools::test_pool_inner_fees_do_not_spend_the_router_float`.

## 2. Bounded Opcode Fuzzing

**Status:** implemented in Phase 2. Hypothesis coverage is in
`router/tests/test_fuzz_router_inputs.py` and
`router/tests/test_fuzz_resources.py`; the real-provider path is in
`router/tests/test_real_opcode_fuzz.py`. The contract and builder now reject
STAMM opup counts above 8. The strict mainnet STAMM measurement suite and live
router-route fuzz pass with the current routed floor of 7 and deployed count 8.

There are two separate problems to test.

### Contract input fuzzing

Use Hypothesis to generate:

- Provider codes
- `Leg.opups`
- Invalid and extreme asset IDs
- Repeated route assets
- Route3 asset combinations
- Incorrect STAMM tier values
- Incorrect creator-pinned app IDs
- Missing and extra foreign assets, applications and boxes
- Non-adjacent funding transactions
- Extra transactions before and after the route
- Multiple quote authorizations
- Incorrect asserting indexes

The expected property is not that every generated group succeeds. The property
is:

```text
Every accepted group satisfies the route invariants.
Every invalid group fails atomically and leaves no state changes.
```

### Opcode boundary testing

`Leg.opups` is caller-controlled for STAMM. The current deployment-specific
maximum is 8, based on the measured routed requirement of 7 plus one safety
unit:

```text
maximum observed required opups + documented safety margin
```

Do not raise this value without remeasuring the deployed STAMM pools. The
contract rejects values above the maximum before calling the budget application,
and the builder rejects an overlarge deployment configuration before emitting a
route.

Test the following values and combinations:

- `opups = 0`
- The normal deployed value
- The maximum accepted value
- Maximum plus one
- A very large `uint64`
- Multiple STAMM legs in one group
- STAMM combined with route3 and quote authorization
- A wide split with the maximum supported budget

LocalNet is insufficient for opcode measurements because the stub pool uses
less budget than real AMMs. Use both layers:

- LocalNet for rejection and group-construction behavior.
- Strict mainnet simulation with `allow_unnamed_resources=False` for real
  provider opcode behavior.

Acceptance criteria:

```text
Every supported route shape has measured opcode headroom.
Every value above the supported opups maximum is rejected cleanly.
```

## 3. Real Pre-Held-Input LocalNet Test

**Status:** implemented in Phase 3. `router_harness.py` provides the setup-only
admin method, and the LocalNet suite now has both a successful pre-held-input
control and an approved-creator malicious-pool rejection.

The normal fixture does not permanently opt the router into the route input
asset. The test-only harness creates that state without adding a production ABI
method.

The safest approach is a test-only harness deployment:

1. Compile a LocalNet-only router harness that adds an admin-only
   `seed_holding(asset)` method.
2. Have that method perform the same zero-amount self-transfer opt-in used by
   `opt_in_asset`.
3. Deploy the harness with the production `Router` logic otherwise unchanged.
4. Call `seed_holding(asset_in)`.
5. Fund the route normally.
6. Execute against a malicious pool that leaves some input behind.
7. Assert rejection and unchanged balances.
8. Run the same held-input group through the cooperative pool and assert that
   the original holding remains while the caller receives the new output.

Do not add a permanent public production method merely to make this test
possible. That would increase the contract attack surface and create another
minimum-balance management path.

## 4. Same-Group Conversion Approval

**Status:** implemented in Phase 4. `convert_and_distribute` now rejects any
outer group containing `set_conversion_pool`, and LocalNet verifies both
rejection and rollback of the attempted approval.

The rejected sequence is:

```text
set_conversion_pool(new_pool)
convert_and_distribute(batch, minimum_out)
```

Both calls are admin-only, so this is not a public theft path. It does weaken
the operational boundary that the pool is approved before treasury funds are
spent.

Implemented resolution:

```text
convert_and_distribute must reject any group containing set_conversion_pool
```

Implementation details:

1. `SET_CONVERSION_POOL_SIGNATURE` is pinned in the contract and client tests.
2. `_assert_no_conversion_pool_approval` scans the outer group for that selector.
3. `convert_and_distribute` calls the helper before spending accrued funds.
4. The call rejects if the setter appears anywhere in the same group.
5. A LocalNet regression test builds approval and conversion
   atomically and expects rejection.
6. The existing separate-group conversion test remains the positive control.

A state-version approach is possible, but it adds global state and complexity
without much benefit here.

## 5. Quote-Signer Co-Signing in the Engine

**Status:** backend and wallet-source implementation complete. Mobile-wallet
runtime verification, production API integration and testnet submission remain.

This remains the most important release gate.

The implemented flow is:

- `router/router/build.py` constructs the quote-signer transaction.
- `engine/core/quote_signer.py` validates and signs the final quote transaction.
- `engine/core/router.py` returns unsigned user transactions plus the signed
  quote transaction metadata.
- `frontend/wallet/src/swapBridge.ts` asks the wallet to sign only user indexes.
- The quote authorization is actually sent by the separate `quote_signer`
  account.

A user wallet cannot sign that transaction because it does not control the
quote-signer account.

### Recommended architecture

Use a backend co-signing step after final group assembly.

`assemble_with_quote()` already performs the important work:

- Assembles the final transaction order.
- Computes route-call indexes.
- Creates the signed-floor note.
- Appends the quote authorization last.

After it returns:

1. Identify the final transaction.
2. Verify that it is sent by the current on-chain `quote_signer`.
3. Sign only that transaction with the quote-signing key.
4. Return a partially signed group to the wallet.
5. Have the wallet sign only the user's transactions.
6. Preserve the existing quote-signer signature.
7. Submit the complete atomic group.

Do not sign the quote transaction before group assembly. Its note and
transaction fields are only correct after all route positions are final.

### Key management

The quote-signing private key must not be exposed to the browser.

Preferred options:

1. An internal signing service backed by a KMS or HSM.
2. A signing worker with the key in a protected secret store.
3. At minimum, a dedicated server-side key file with strict permissions and no
   logging.

Keep the quote signer separate from the admin key, voucher-signing key and any
normal transaction-signing key.

### API shape

The API now returns unsigned transactions plus partial-signing metadata, for
example:

```json
{
  "transactions": [
    {
      "index": 0,
      "signed": false,
      "msgpack": "..."
    },
    {
      "index": 6,
      "signed": true,
      "sender": "QUOTE_SIGNER",
      "msgpack": "..."
    }
  ],
  "quote": {}
}
```

Alternatively, return a partially signed transaction group in a format the
wallet adapter already supports. The requirements are:

- The quote-signer signature is present before the wallet signs.
- The client cannot replace the signed transaction.
- The client cannot change the group after the quote signature is applied.
- The server verifies the final group before returning it.

### Required engine tests

Add tests under `engine/core/tests/test_router.py` for:

- A routed group includes exactly one quote authorization.
- The authorization sender is the configured signer.
- The authorization is the final transaction.
- The authorization is signed by the quote signer.
- User transactions remain unsigned for the wallet.
- A restricted deployment raises `RouterUnavailable`.
- A deployment with `restricted=False` proceeds.
- A rotated quote signer causes the old signer to be rejected.
- An expired quote authorization is rejected by simulation or LocalNet.
- A malformed or substituted quote authorization is rejected.

The most important test should use real Algorand transaction serialization and
signature verification rather than mocks.

## 6. Deployment and Bytecode Verification

**Status:** release-manifest generation and independent verification tooling are
implemented in the worktree. No deployment was submitted by Phase 6.

`scripts/deploy.py` now creates a durable release manifest containing the exact
artifact identity after a successful deployment. `scripts/verify_deployment.py`
recompiles the source independently and compares the manifest with the deployed
application.

Add a release manifest containing:

```json
{
  "network": "mainnet",
  "application_id": 0,
  "source_commit": "...",
  "compiler": "puyapy 5.9.0",
  "restrict_to_admin": false,
  "template_values": {},
  "approval_teal_sha256": "...",
  "clear_teal_sha256": "...",
  "approval_bytecode_sha256": "...",
  "clear_bytecode_sha256": "...",
  "extra_pages": 1,
  "global_schema": {}
}
```

### Pin the compiler

The dependency is now pinned for release builds:

```text
puyapy==5.9.0
```

Any compiler upgrade must trigger a new artifact review and manifest.

### Independent verification procedure

`scripts/verify_deployment.py` now performs the following independently:

1. Checks out the release source.
2. Compiles with the pinned Puya version.
3. Applies the exact network template values.
4. Computes TEAL and bytecode hashes.
5. Reads the deployed application metadata.
6. Decodes the deployed approval and clear programs.
7. Compares deployed hashes against the manifest.
8. Verifies the global schema.
9. Verifies the application creator/admin state.
10. Verifies `quote_signer`, conversion pool and fee state.

The verifier should be independently runnable and should fail on:

- Any leftover `TMPL_` variable.
- A compiler-version mismatch.
- A template mismatch.
- A bytecode hash mismatch.
- An unexpected extra-page count.
- An unexpected `RESTRICT_TO_ADMIN` build.

The strongest `RESTRICT_TO_ADMIN` check is behavioral:

- Build a correctly co-signed route from a non-admin account.
- Confirm it fails against the restricted deployment.
- Confirm the same route executes against the unrestricted deployment.

This verifies compiled behavior rather than trusting a configuration flag.

## 7. Recommended Release Sequence

Target-network provider/conversion exercise and monitoring implementation are
specified in `POST-DEPLOYMENT-OPERATIONS-PLAN.md`. Deployment verification
steps are in `DEPLOYMENT-VERIFICATION.md`.

Use a fresh application ID. `RESTRICT_TO_ADMIN` is compile-time and cannot be
changed on the existing application.

1. Pin the compiler and generate the release manifest.
2. Deploy the patched build with `RESTRICT_TO_ADMIN = 1`.
3. Fund it and configure `quote_signer`.
4. Configure and verify `conversion_pool`.
5. Run the complete LocalNet suite.
6. Run strict testnet integration with real quote-signer co-signing.
7. Run one real restricted mainnet canary route as admin.
8. Verify deployed bytecode against the manifest.
9. Deploy the identical source and templates with `RESTRICT_TO_ADMIN = 0`.
10. Run a non-admin, quote-signed route against the unrestricted deployment.
11. Run route3 simulation and the supported-provider matrix.
12. Run the conversion and final-sweep regression.
13. Update `router/deployments.py` with the new application ID and
    `restricted=False`.
14. Deploy the engine signing service and verify its key/configuration.
15. Only then remove the operational restriction from the production path.

The current engine metadata has:

```python
MAINNET = Deployment(..., restricted=True)
```

Keep this true until the restricted canary is complete. After a new
unrestricted deployment is independently verified, update the application ID
and set `restricted=False` in the same release change as the signing-service
configuration.

## 8. Launch Gate

Do not lift `RESTRICT_TO_ADMIN` until all of the following are true:

```text
110 LocalNet tests pass
engine co-signing integration passes
strict testnet route passes
deployed bytecode matches the release manifest
non-admin unrestricted route passes
conversion regression passes
human Algorand security review is complete
```
