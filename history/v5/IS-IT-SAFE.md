# Is the Router Safe? (Audit v5)

**Executive Verdict:** **The contract is sound, and it is deployed restricted
on purpose.** No critical or high-severity vulnerability was found. That is not
the same as a clearance for unrestricted public use, and this document said it
was until it was corrected on 2026-08-29 — see [CORRECTIONS.md](CORRECTIONS.md).

Mainnet application `3688554446` is compiled with `RESTRICT_TO_ADMIN`: `route`
and `route3` refuse every caller but the admin. It stays that way until an
**Algorand-experienced human** has reviewed the audit work, because every audit
in this series so far — including this one — was produced by an AI system, and
this one got the deployment's own access control backwards.

---

## The Short Answer

The smart router is an Algorand application designed to execute swaps across multiple decentralized exchanges (Tinyman v2, Pact, Pact MWPT, STAMM, and AlgoFi) within an atomic transaction group.

It holds **no long-term user balances**, carries **no permanent inventory**, and strictly measures swap outputs using **on-chain holding deltas** rather than trusting third-party AMM return values. All user trades are protected by a **cryptographically co-signed minimum-output floor** that prevents malicious frontends, sandwich attackers, or front-running bots from extracting slippage.

---

## Key Safety Questions

### 1. Can an attacker steal my tokens while I swap?
**No.** 
- The router only accepts an input transfer that immediately precedes the swap call in the same atomic group (`payment.group_index + 1 == Txn.group_index`) and comes directly from your address (`payment.sender == Txn.sender`).
- The router verifies that the entire input is spent (`_assert_input_spent`) and transfers the exact realised output back to your account in the same transaction.
- If any leg of the swap produces less than the signed floor, the entire atomic group aborts, reverting all transfers instantly.

### 2. Can a compromised frontend or dApp trick me into a bad trade?
**No.**
- In older router architectures, a frontend could set `minimum_received = 0`.
- In this contract, the minimum output is verified via a note signed by the backend `quote_signer` key. The router reads the authenticated floor directly from the transaction note. A frontend cannot alter this floor without breaking the signature, which causes Algorand consensus to reject the transaction.

### 3. Can an attacker trick the router into sending funds to a fake AMM pool?
**No.**
- **Tinyman v2:** The router derives the pool logic signature address on-chain using SHA-512/256 over the known template hash. A caller cannot supply an arbitrary pool address.
- **Pact (Standard & Stableswap):** The pool's application creator is verified on-chain against a pinned list of official Pact factory addresses (`PACT_POOL_CREATORS`).
- **Pact MWPT (Managed Weighted Pools):** Verified against the official MWPT factory creator address. The router directly queries the pool's global state (`vault` key) to locate the authentic vault escrow before dispatching funds.
- **STAMM:** The pool's application creator is verified on-chain against `STAMM_POOL_CREATORS`.
- **AlgoFi:** The pool ID must be present in a strictly compiled whitelist of official AlgoFi pool applications.

### 4. Can the contract rekey or close my Algorand account?
**No.**
- Every entry point runs `_assert_group_is_clean()`, which inspects every transaction in the entire atomic group.
- If any transaction contains a non-zero `RekeyTo`, `CloseRemainderTo`, or `AssetCloseTo`, the contract immediately rejects the call with an assertion failure.

### 5. What powers does the Administrator have?
- The Administrator key is strictly bounded:
  - Can set the protocol fee rate up to a hard ceiling of 100 basis points (1.00%), enforced by `MAX_FEE_BPS`.
  - Can set the treasury conversion pool and escrow receiver for protocol revenue.
  - Can rotate the quote signer and voucher signer keys.
  - Can delete the contract only when accrued fees are zero and no asset holdings remain open.
- The Administrator **cannot** access or confiscate user funds during a swap.

### 6. What about the new Pact MWPT and Liquid Staking features?
- **Pact MWPT:** Fully supported and tested. The contract independently verifies the vault address from pool global storage on-chain, ensuring deposits cannot be diverted.
- **Liquid Staking Assets:** Priced from their **real AMM pools first**; the protocol's redemption rate answers only when the cache holds no reserve pool for the asset. (This document had the two the wrong way round until 2026-08-29.)
- **Dust Sweep Subsystem:** Provides portfolio cleanups, enforcing exact minimum balance recoveries and user-controlled asset forfeitures. **Read `findings/I2` before relying on that last phrase**: a forfeit of a *priced* dust holding is included by default rather than opted in to, and until commit `1c128f2` an *unpriced* holding could be forfeited on a tick with no value test of any kind.

---

## Security Verification Summary

| Protection Mechanism | Implementation | Status |
|-----------------------|----------------|--------|
| **Slippage & MEV Protection** | Backend Co-signed Note Floor | Verified |
| **Input Conservation** | Balance Delta & `_assert_input_spent` | Verified |
| **Provider Authentication** | On-chain derivation & creator pinning | Verified |
| **Group Safety & Hygiene** | Full group Rekey/Close inspection | Verified |
| **Float Isolation** | Same-group opt-in/close lifecycle | Verified |
| **Zero-Fee Inner Txns** | All inner txns `fee=0`, pooled on outer call | Verified |
| **Treasury Isolation** | Admin-only separate-group conversion | Verified |
