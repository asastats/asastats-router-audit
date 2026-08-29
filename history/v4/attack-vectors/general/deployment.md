# Deployment Attack Vectors

These vectors analyze attacks related to the deployment configuration: template variables, compiler version, bytecode-vs-source verification, and the `RESTRICT_TO_ADMIN` flag.

## Vectors

### GENERAL-DEPLOY-01: Compiler version drift
- **Verdict:** Defended.
- **Code:** `puyapy 5.9.0` is pinned in `requirements.txt` and the deployment script verifies the version.
- **Test:** `tests/test_build.py::test_compiler_version_pinned`.

### GENERAL-DEPLOY-02: Template variable misconfiguration
- **Verdict:** Accepted by design.
- **Code:** Template variables (`PACT_POOL_CREATORS`, `STAMM_POOL_CREATORS`, `ALGOFI_POOLS`, `RESTRICT_TO_ADMIN`, etc.) are set at deploy time. A misconfiguration can lock the router (e.g., wrong creator address).
- **Note:** This is the I1 v4 finding (`RESTRICT_TO_ADMIN` still in source). The flag is being removed in the next compile.
- **Test:** Manual.

### GENERAL-DEPLOY-03: Bytecode-vs-source mismatch
- **Verdict:** Defended.
- **Code:** Deployment script verifies that the compiled TEAL matches the audited source via `sha256sum`.
- **Test:** Manual at deploy time.

### GENERAL-DEPLOY-04: UpdateApplication after deployment
- **Verdict:** Defended.
- **Code:** The router has no `UpdateApplication` handler. Updates are blocked at the code level.
- **Test:** Tealer `unprotected-updatable` detector shows 0 results.

### GENERAL-DEPLOY-05: DeleteApplication before draining all assets
- **Verdict:** Defended (L1 v3).
- **Code:** `delete_application` asserts `total_assets == 0` and `accrued == 0`.
- **Test:** `tests/test_router_contract.py::test_delete_requires_empty_app`.

### GENERAL-DEPLOY-06: Contract migration without updating creator list
- **Verdict:** Accepted by design (residual).
- **Code:** The Pact MWPT factory creator is hardcoded in `_pact_leg`. If the upstream Pact team migrates, the router must be redeployed with the new address.
- **Note:** This is the residual risk documented in DISCLAIMER.md §5.4.
- **Test:** n/a.
