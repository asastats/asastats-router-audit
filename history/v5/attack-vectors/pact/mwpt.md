# Attack Vectors: Pact MWPT Integration & Vault Resolution (v5)

## 1. Attack Vector Overview
Pact Managed Weighted Pools (MWPT) differ fundamentally from standard constant-product pools:
1. **Separated Escrow (Vault):** Reserves are not held in the pool account; they reside in a shared Vault application. Deposits must go to the Vault address.
2. **Dynamic Weight Curves:** Swaps execute across asymmetric asset weights ($w_{\text{in}} \neq w_{\text{out}}$) using power-fraction math.
3. **Custom Selector:** MWPT calls use selector `PACT_MWPT_SWAP` (`0x035942b0`).

---

## 2. Specific Vectors & Evaluations

### V-MWPT-01: Vault Redirection & Deposit Misrouting
- **Attack:** An attacker passes a fake vault application address on the leg, stealing the input deposit intended for the pool.
- **Evaluation:**
  - The router does not take the vault address from caller arguments.
  - In `_pact_leg`, the router detects an MWPT pool via creator matching (`H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM`).
  - It dynamically reads the `vault` global state key directly from the pool contract via `op.AppGlobal.get_ex_uint64(pool_app, Bytes(b"vault"))`.
  - It resolves the vault address via `op.AppParamsGet.app_address(Application(vault))` and sets `escrow = vault_address`.
  - The deposit goes exclusively to the authentic on-chain vault escrow.
- **Verdict:** **DEFENDED.**

### V-MWPT-02: Missing Vault in Foreign Applications Array
- **Attack:** The transaction group omits the vault application from the foreign apps array, causing the pool or router to panic on unlisted state reads.
- **Evaluation:** `router.contract.route_references` automatically includes the MWPT vault in the outer transaction's application references array. On-chain, `_pact_leg` asserts `assert vault_exists, "the MWPT vault must be named by the group"`.
- **Verdict:** **DEFENDED.**

### V-MWPT-03: Asymmetric Weight Math Off-Chain Drift
- **Attack:** Off-chain quoter calculates floating-point output that overestimates on-chain integer yield, causing the signed floor to revert valid trades.
- **Evaluation:** `router/curves.py:pact_mwpt_out` implements high-precision Newton-Raphson exponentiation. Tests in `tests/test_pact_mwpt.py` confirm exact match ($\pm 0$ drift) against on-chain simulated outcomes.
- **Verdict:** **DEFENDED.**

### V-MWPT-04: Zero-Output Branch on Deep Asymmetric Depletion
- **Attack:** A tiny swap through an extremely unbalanced MWPT pool rounds output to 0, locking funds in the vault without returning value.
- **Evaluation:** If output is 0, `_held(asset_out) - before` evaluates to 0, which fails the non-zero quote floor check (`_group_paid() >= minimum_received`), reverting the entire atomic group safely.
- **Verdict:** **DEFENDED.**
