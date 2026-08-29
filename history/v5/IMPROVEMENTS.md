# Smart Contract Improvements & Historical Optimizations (v5)

This document tracks all contract-level and engine-level improvements implemented throughout the lifecycle of the ASA Stats Smart Router, including fixes delivered in v1, v2, v3, v4, and the latest v5 deployment.

---

## 1. Summary of Implemented Improvements (v1 → v5)

| Version | ID / Area | Improvement Description | Impact & Resolution |
|:-------:|:---------:|-------------------------|---------------------|
| **v5** | **MWPT-1** | On-chain dynamic MWPT vault resolution via `AppGlobal.get_ex_uint64` and escrow deposit routing | Eliminates confused-deputy risk on weighted pools; closes v4 L2 |
| **v5** | **MATH-1** | High-precision Newton-Raphson & Decimal math for asymmetric weighted pool quoting | Eliminates off-chain drift from on-chain BigInt math; closes v4 M1 |
| **v5** | **AUTH-1** | Strict verification of quote authorisation application ID, arg count, and selector | Prevents spoofing of quote budget calls |
| **v5** | ~~**DEP-1**~~ | ~~Removal of `RESTRICT_TO_ADMIN` check for production deployment `3688554446`~~ **RETRACTED 2026-08-29 — this never happened.** `3688554446` was deployed *with* `--restrict`; its manifest records `RESTRICT_TO_ADMIN = 1` and the engine refuses to build a mainnet group for any caller but the admin. v4's I1 is **not** closed | The restriction is deliberate and remains in force |
| **v5** | **RATE-1** | Consensus rate oracle resolver for liquid staking assets without direct liquidity | Expands routing coverage to liquid staking tokens without depth distortion |
| **v5** | **SWEEP-1** | Complete dust sweep subsystem with portfolio classification and forfeiture controls | Wallet and contract cleanup; 323 tests across the four suites (router 111, engine 61, widget jest 121, browser 30) as of the audited revision |
| **v4** | **MWPT-0** | Integration of Pact Managed Weighted Pool (MWPT) swap selector `0x035942b0` | Extends AMM coverage to weighted pools |
| **v3** | **OPUP-1** | Capping of STAMM opup requests to `MAX_STAMM_OPUPS = 8` | Prevents caller-induced inner txn exhaustion |
| **v3** | **CODE-1** | Dead code removal for non-STAMM opup dispatch | Saved 66 TEAL instructions |
| **v3** | **INP-1** | Pre-held ASA input conservation assert (`_assert_input_spent`) | Prevents stranded inputs in pre-held accounts |
| **v3** | **ADJ-1** | Funding transaction adjacency assertion (`payment.group_index + 1 == Txn.group_index`) | Hardens group layout validation |
| **v3** | **SEP-1** | Same-group conversion pool approval separation (`_assert_no_conversion_pool_approval`) | Prevents atomic conversion pool substitution |
| **v2** | **FLOOR-1**| Backend co-signed transaction note floor architecture | Eliminates widget-controlled zero floor vulnerability (H1) |
| **v1** | **TREAS-1**| Admin-only conversion pool gating (`convert_and_distribute` restricted to admin) | Eliminates permissionless fee drain vulnerability (C1) |
| **v1** | **PATH-1** | Pairwise distinct asset assertions on multi-hop routes | Prevents route cycling and accounting confusion (M1) |
| **v1** | **ADDR-1** | Zero-address rejection in all administrative setters | Eliminates blackhole admin risk (L2) |

---

## 2. Deep Dive: v5 Implemented Improvements

### 2.1 MWPT On-Chain Dynamic Vault Resolution (Closes v4 L2)
In Pact MWPT pools, token reserves reside in a shared Vault application rather than the individual pool application account. In v5, the smart contract dynamically extracts the authentic vault application ID from the pool's global state and verifies its application address on-chain:

```python
if is_mwpt:
    vault, has_vault = op.AppGlobal.get_ex_uint64(pool_app, Bytes(b"vault"))
    assert has_vault, "an MWPT pool names its vault"
    vault_address, vault_exists = op.AppParamsGet.app_address(
        Application(vault)
    )
    assert vault_exists, "the MWPT vault must be named by the group"
    escrow = vault_address
```
All initial transfers are dispatched directly to `escrow` (the verified vault address), eliminating any possibility of fund misdirection.

### 2.2 Quote Authorisation Structure Hardening
In v5, the signed floor verification routine (`_signed_floor`) strictly asserts the exact structure of the terminating transaction in the group:
```python
assert authorisation.sender == self.quote_signer, "the group is not co-signed by the quote signer"
assert authorisation.type == TransactionType.ApplicationCall, "the quote authorisation is not an application call"
quote_call = gtxn.ApplicationCallTransaction(Global.group_size - 1)
assert quote_call.app_id == Global.current_application_id, "the quote authorisation targets another application"
assert quote_call.num_app_args == 1, "malformed quote authorisation"
assert quote_call.app_args(0) == arc4.arc4_signature(POOL_BUDGET_SIGNATURE), "the quote authorisation is not a pool budget call"
```
This guarantees that no external application call can masquerade as the quote authorization transaction.

---

## 3. Future Roadmap & Non-Breaking Recommendations

1. **ARC-56 Specification Export:** Fully integrate ARC-56 application specification files in automated deployment pipelines for standardized third-party client consumption.
2. **Dynamic Opcode Metering:** As the AVM evolves, continue monitoring opcode pooling across 4-hop routes if reference limits expand in future AVM versions.
3. **Multi-Sig Admin Rotation:** Transition production admin keys to a multi-signature Algorand account or timelocked controller as protocol TVL scales.
