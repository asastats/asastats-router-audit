# Provider Integration Attack Vectors (v5)

This domain analyzes the security of cross-contract calls to each supported DEX protocol: Tinyman v2, Pact, STAMM, and AlgoFi.

---

## Vector Categories & Coverage

| Category File | Focus DEX | Authentication Method | Verdict |
|---------------|-----------|-----------------------|:-------:|
| [tinyman.md](tinyman.md) | Tinyman v2 | Derived LogicSig address template | **DEFENDED** |
| [pact.md](pact.md) | Pact (Std & Stableswap) | Creator address pinning (`PACT_POOL_CREATORS`) | **DEFENDED** |
| [stamm.md](stamm.md) | STAMM AMM | Creator address pinning (`STAMM_POOL_CREATORS`) | **DEFENDED** |
| [algofi.md](algofi.md) | AlgoFi Defunct Pools | Compiled immutable whitelist (`ALGOFI_POOLS`) | **DEFENDED** |
