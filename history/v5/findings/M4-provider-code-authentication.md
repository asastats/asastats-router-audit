# Finding M4: External Provider Pool Authentication

- **Severity:** Medium
- **Category:** Cross-Contract Authentication / Spoofing
- **Location:** `contracts/router_app.py:_swap_leg`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Allowing callers to pass unauthenticated pool application IDs would permit routing into malicious contracts designed to steal transferred assets.

---

## 2. Remediation in Code
Implemented on-chain authentication per provider:
1. **Tinyman v2:** Derived on-chain via SHA-512/256 logic signature template hash (`_tinyman_v2_pool`).
2. **Pact:** Verified on-chain via `_assert_created_by` against pinned `PACT_POOL_CREATORS`.
3. **Pact MWPT:** Verified against official MWPT factory creator address + dynamic on-chain vault resolution.
4. **STAMM:** Verified on-chain via `_assert_created_by` against pinned `STAMM_POOL_CREATORS`.
5. **AlgoFi:** Verified on-chain via `_assert_listed` against immutable `ALGOFI_POOLS` whitelist.

---

## 3. Verification Evidence
- `TestThePoolPinConstants` suite verifies all creator arrays and strides.
- `TestRouting::test_a_fake_pool_is_rejected` passes.
