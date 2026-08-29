# Router Deployment Verification Runbook

This runbook describes how to deploy and independently verify a router release.
It does not authorize deployment by itself. Mainnet deployment requires human
approval and the launch gates in the audit report.

## 1. Release Inputs

Prepare a clean source checkout and record:

- Source revision in `RELEASE_SOURCE_COMMIT`.
- Puya version, pinned by `router/requirements.txt`.
- Network and exact template values.
- Intended `RESTRICT_TO_ADMIN` value.
- Intended application ID, once deployed.
- Quote-signer public address.
- Approved conversion-pool `Leg`.

The release manifest must never contain mnemonics, private keys or access
tokens.

## 2. Preflight

From the router checkout:

```bash
python --version
puyapy --version
python -m pytest tests/test_router_contract.py -q
python -m pytest tests/test_contract_localnet.py -q
python -m pytest tests/test_stamm_opups.py -q
```

The LocalNet and STAMM tests must pass before any target-network deployment.

Verify signer file permissions without printing their contents:

```bash
stat -c '%a %n' \
  ~/.config/asastats/router-signer-testnet.mnemonic \
  ~/.config/asastats/router-signer-mainnet.mnemonic
```

Expected permissions are `600` or stricter. The backend signer also rejects
group/world-readable files and verifies the derived address against on-chain
state.

## 3. Restricted Canary Deployment

Deploy a fresh restricted application first. Never reuse an old application ID
for a changed approval program.

Example testnet command:

```bash
export RELEASE_SOURCE_COMMIT="<reviewed-source-revision>"
python scripts/deploy.py testnet \
  --restrict \
  --manifest build/releases/router-testnet-canary.json
```

Record the returned application ID. Configure the deployment in a separate
admin transaction sequence:

1. Fund the application account.
2. Set the quote signer.
3. Set the fee state required for the test environment.
4. Set and read back the approved conversion pool.

Do not combine conversion-pool approval with conversion. Phase 4 explicitly
rejects that shape.

## 4. Generate and Inspect the Manifest

The deployment script writes a manifest containing:

- Application ID and creator.
- Source revision.
- Exact compiler version.
- Exact template values.
- `restrict_to_admin`.
- Global schema and extra pages.
- Approval and clear TEAL hashes.
- Approval and clear bytecode hashes.

Inspect the manifest for correctness, but do not edit its artifact fields by
hand. If a field is wrong, discard the release and rebuild it.

## 5. Independent Bytecode Verification

Run the verifier from the same reviewed source revision:

```bash
python scripts/verify_deployment.py \
  build/releases/router-testnet-canary.json \
  --quote-signer <expected-testnet-quote-signer> \
  --conversion-pool-hex <56-byte-encoded-leg> \
  --fee-bps 0
```

The verifier independently recompiles the source and fails on:

- Missing source revision.
- Compiler mismatch.
- Missing or unsubstituted template values.
- TEAL hash mismatch.
- Approval or clear bytecode mismatch.
- Global schema mismatch.
- Creator mismatch.
- Extra-page mismatch.
- `RESTRICT_TO_ADMIN` mismatch.
- Quote-signer mismatch when supplied.
- Fee-state mismatch when supplied.

The verifier output and manifest should be stored with the release record.

## 6. Behavioral Restriction Check

Artifact hashes alone do not prove the behavior of `RESTRICT_TO_ADMIN`. Use a
funded non-admin test account and a valid backend-signed route:

- The restricted canary must reject the non-admin route.
- The same route shape must execute when tested against an unrestricted canary
  built from the same source and templates except for the restriction value.

The restricted rejection must be caused by the contract restriction, not by an
unfunded account, missing signer, malformed group or missing resource.

## 7. Target-Network Verification

After the restricted artifact is verified:

1. Run the target-network provider matrix in
   `POST-DEPLOYMENT-OPERATIONS-PLAN.md`.
2. Exercise conversion through the approved pool in a separate group.
3. Run the final-sweep path below the conversion floor.
4. Verify no temporary asset holdings remain.
5. Verify the quote signer and wallet partial-signing flow.
6. Record transaction IDs, rounds, app IDs and artifact hashes.

STAMM is mainnet-only in the current environment because its applications are
not deployed on testnet. Its target-network verification must therefore use
strict mainnet simulation first, followed by a controlled mainnet canary.

## 8. Unrestricted Release

`RESTRICT_TO_ADMIN` is compile-time. Do not change it on the restricted app.
Deploy a new application with the same verified source, compiler and template
values except `RESTRICT_TO_ADMIN = 0`:

```bash
python scripts/deploy.py mainnet \
  --confirm \
  --manifest build/releases/router-mainnet-unrestricted.json
```

Before serving users:

- Run `verify_deployment.py` against the new app.
- Run the non-admin behavior check.
- Run the wallet-signature testnet equivalent against the release build.
- Update `router/deployments.py` with the new app ID and `restricted=False`.
- Deploy the matching engine and wallet artifacts.
- Confirm monitoring is active.

No release is complete until the deployed application ID, manifest and runtime
artifacts are recorded together.
