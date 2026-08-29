# Attack Vectors: AlgoFi Defunct Pool Integration (v5)

## 1. Attack Vector Overview
AlgoFi AMM pools are defunct protocols that retain active secondary market liquidity. Because the factory is inactive, pools are authenticated via an explicit whitelist.

---

## 2. Specific Vectors & Evaluations

### V-ALGOFI-01: Injection of Unvetted AlgoFi Pool IDs
- **Attack:** A caller supplies a defunct or attacker-controlled application claiming to be an AlgoFi pool.
- **Evaluation:** `_algofi_leg` invokes `_assert_listed(leg.app.as_uint64(), TemplateVar[Bytes]("ALGOFI_POOLS"))`. The contract compares the pool ID against an immutable 23-element byte sequence compiled into the contract bytecode. Unlisted pools fail immediately.
- **Verdict:** **DEFENDED.**

### V-ALGOFI-02: AlgoFi Manager App ID Spoofing
- **Attack:** A caller supplies an arbitrary `hub` application ID for the AlgoFi manager.
- **Evaluation:** `_swap_leg` asserts `assert leg.hub.as_uint64() == TemplateVar[UInt64]("ALGOFI_MANAGER_APP_ID")`, ensuring the genuine manager is referenced.
- **Verdict:** **DEFENDED.**

### V-ALGOFI-03: AlgoFi Position Array Misalignment
- **Attack:** An attacker passes swap arguments in reversed order to confuse AlgoFi's "Swap Exact For" (SEF) method.
- **Evaluation:** `_algofi_leg` explicitly branches on whether `asset_in == 0` or `asset_out == 0`, formatting the application argument tuple to match AlgoFi's exact expected order.
- **Verdict:** **DEFENDED.**
