# Attack Vectors: Provider Spoofing & Pool Authentication

## Overview
Cross-DEX routers face the risk that an attacker submits a fake, malicious pool contract masquerading as a legitimate AMM (Tinyman, Pact, STAMM, AlgoFi) to steal caller funds.

---

### Detailed Attack Vector Analysis

#### AV-SPO-01: Tinyman v2 Pool LogicSig Spoofing (Finding T5)
- **Attack Description:** An attacker passes a custom logic signature address as the Tinyman v2 pool to intercept input funds.
- **Risk Level:** CRITICAL
- **Verdict:** **Defended**
- **Mechanism:** The router **never accepts pool addresses from the caller**. In `_tinyman_v2_pool()`, the contract dynamically reconstructs the Tinyman v2 logic signature bytecode using the pinned `TINYMAN_V2_APP_ID` and sorted asset IDs, hashing it via `sha512_256` to derive the authentic pool address.

#### AV-SPO-02: Pact AMM Fake Pool Deployment (Finding M3 / M4)
- **Attack Description:** An attacker deploys a contract mimicking Pact's interface and passes its App ID to the router.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** In `_pact_leg()`, the contract invokes `_assert_created_by(leg.app.native, TemplateVar[Bytes]("PACT_POOL_CREATORS"))`. The on-chain creator of the application is verified against the pinned official Pact creator accounts before any call is made.

#### AV-SPO-03: STAMM AMM Fake Pool Deployment (Finding M3 / M4)
- **Attack Description:** An attacker deploys a malicious STAMM pool to drain swap deposits.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** In `_stamm_leg()`, the pool application ID is verified via `_assert_created_by(leg.app.native, TemplateVar[Bytes]("STAMM_POOL_CREATORS"))`.

#### AV-SPO-04: AlgoFi Defunct Pool Injection (Finding M3)
- **Attack Description:** An attacker provides an arbitrary application ID claiming it is an AlgoFi pool.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** Because AlgoFi pools were created permissionlessly, the contract checks `leg.app` against a curated, compile-time pinned whitelist (`ALGOFI_POOLS`) containing only liquid, verified pools, and pins the manager ID to `ALGOFI_MANAGER_APP_ID`.
