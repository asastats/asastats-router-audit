# Is the Smart Router Safe? (v4 Plain-English Security Review)

## Quick Verdict: **YES**

The ASA Stats Smart Router (`router/contracts/router_app.py`) is secure under both restricted and unrestricted deployment models. The router has gained **Pact MWPT (Managed Weighted Pool)** support since the v3 audit, and that addition introduces **no critical or high-severity vulnerabilities**.

---

## What changed in v4

The router now supports **Pact MWPT pools** in addition to Tinyman v2, Pact constant-product/stableswap, STAMM, and AlgoFi. MWPT is a weighted-pool AMM (pools with asset weights like 20/80 instead of 50/50), and the router treats MWPT pools as a sub-type of Pact — same on-chain dispatch path, different selector byte (`0x035942b0`) for the swap method, and a different vault reference for box reads.

In plain terms: **no new way to steal funds; one new way for off-chain quotes to drift by 1 microunit from on-chain output (and the drift is always in the pool's favour).**

---

## Key Questions Answered

### 1. Can someone steal my funds during a swap?
**No.**
- The router only takes custody of your funds for the duration of the single atomic transaction group.
- The output tokens you receive must meet or exceed the floor quoted by the backend quote signer (`_signed_floor`). If any pool underpays, the entire swap reverts instantly and you keep your original funds.
- Payouts are hardcoded to return directly to your account address (`Txn.sender`).

### 2. Can a hacked frontend give me an unfair price?
**No.**
- The minimum output floor is **digitally signed by the backend quote server** and verified on-chain. A compromised frontend cannot alter or lower this floor.
- The signed note binds the floor to (application ID, caller, output asset, per-position input amounts, asserting index), so a quote for one trade cannot be replayed on another.

### 3. Can a MWPT pool steal intermediate assets?
**No.**
- The router authenticates MWPT pools the same way it authenticates legacy Pact pools: by checking that the pool was deployed by the official Pact creator (`H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM` for MWPT, plus the legacy creator address(es)).
- The on-chain code path through `_pact_leg` is unchanged; only the first argument to the inner application call differs (the selector byte).
- The router measures output by its own balance delta, not by anything the pool reports.

### 4. Can a weight-asymmetric pool (e.g., 20/80) be used to game the quote?
**Mostly no.**
- The MWPT curve math in `router/curves.py:pact_mwpt_out` uses IEEE-754 doubles, which can drift by 1 microunit from the on-chain BigInteger computation. The drift is *always in the pool's favour* — you receive at least as much as the contract delivers, but the off-chain quote may promise 1 microunit more than the on-chain swap actually pays.
- **Finding M1.** This is a Medium severity issue; the recommended fix is to rewrite `pact_mwpt_out` in pure integer arithmetic.
- In practice, the floor mechanism still protects you: if the off-chain quote says `1,000,001` and the on-chain delivers `1,000,000`, the contract asserts `≥ quoted_floor`, which still passes.

### 5. Can an attacker drain the router's ALGO balance?
**No.**
- Every inner transaction uses `fee = 0`. The outer route call pools its own fees via `route_fee` (computed off-chain).
- Any temporary asset opt-in opened during a swap is closed when the swap finishes.

### 6. Can the admin steal user swaps or protocol fees?
**No for user swaps; bounded for fees.**
- The admin cannot alter user swaps or redirect trade payouts.
- Platform fees are capped in code at 1.0% (`MAX_FEE_BPS = 100`).
- Fee conversions can only be sent to the configured platform escrow account.

### 7. Is the AlgoFi whitelist still safe?
**Yes, by design, but it should be tightened.**
- The AlgoFi pool list was widened since v3 (now 23 pools, up from a smaller curated list). The list is admin-curated and intended for AlgoFi's defunct pools.
- **Finding I2 (new in v4).** The widening policy is undocumented; this is a hygiene observation, not a vulnerability.

### 8. Is the `RESTRICT_TO_ADMIN` flag still on?
**Partially.**
- Mainnet runs unrestricted (`RESTRICT_TO_ADMIN = 0`).
- Testnet runs restricted (`RESTRICT_TO_ADMIN = 1`) — this is intentional during the gradual rollout.
- **Finding I1 (new in v4).** The flag should be removed entirely for the next compile to avoid future confusion.

---

## Summary of Completed Security Audits

| Audit Stage | Focus Area | Status |
|---|---|---|
| **Audit v1** | Initial architecture, conversion pool drain (C1), path sanitization | Patched |
| **Audit v2** | Backend quote signer (H1), pre-held input conservation (M3), adjacency (M2) | Patched |
| **Audit v3** | Institutional synthesis, 134 attack vectors, Trail of Bits scanner, dead-code cleanup (I1) | Complete & Verified |
| **Audit v4** | **MWPT integration, weight-asymmetry quoting drift (M1), 27 MWPT vectors, no regressions** | **Complete & Verified** |

---

## What is at stake (re-stated for clarity)

Three pools of value, in decreasing order of importance:

1. **Each caller's trade, mid-route.** The contract holds the caller's entire input, then the intermediate, then the output. A routing-path flaw could steal one trade per group, repeatedly, from whoever is trading.
2. **The platform's accrued fees.** `convert_and_distribute` swaps accrued ALGO into ASASTATS. This is admin-only, with a pre-approved pool. Nothing here protects the accrued fees from the admin key itself, which is acceptable because it's the platform's own money.
3. **The application's float.** A small ALGO balance used to lend minimum balances for opt-ins. Draining it is an operational annoyance, not a user loss.

---

## What is already defended (re-confirmed in v4)

- The contract refuses any group that rekeys or closes an account (`_assert_group_is_clean`).
- Tinyman v2 pool addresses are derived inside the contract, not supplied by the caller.
- The contract measures what a leg actually paid by its own balance delta, not by anything a pool reports.
- Inner transactions carry zero fees, so fees cannot silently subtract from an ALGO-denominated leg.
- The platform fee is capped at 100 bps.
- Opt-ins are tied to a route in the same group, so the float cannot be locked one junk asset at a time.
- **MWPT pools are authenticated by the same creator check as legacy Pact pools.** (v4)
- **MWPT output is measured by balance delta, same as legacy Pact output.** (v4)

---

## What v4 adds

1. **MWPT support.** New provider path through `_pact_leg`; no new authentication surface.
2. **5 new findings** (M1, L1, L2, I1, I2), none critical/high.
3. **3 concrete improvements** documented in `IMPROVEMENTS.md` to apply before the next deployment.
4. **No regressions** — every v3 finding remains patched, verified-defended, or accepted by design.

---

## When will it be safe to remove the admin restriction (already removed on mainnet)?

For **testnet** and any future **mainnet redeployment** that re-introduces `RESTRICT_TO_ADMIN = 1`:

After:
- The three v4 improvements (M1, L2, I1) are applied.
- A human Algorand auditor signs off on the contract (this is the only item the AI cannot advance).
- Differential testing against real MWPT pools confirms the on-chain curve matches the off-chain curve to ±0 microunit.

Removing the restriction before those three items is a deliberate risk.

---

## Where to look if you have questions

- **"What does each finding actually say?"** → [REPORT.md](REPORT.md) §3.
- **"Is there a specific attack I'm worried about?"** → [attack-vectors/](attack-vectors/).
- **"What should we change in the code?"** → [IMPROVEMENTS.md](IMPROVEMENTS.md).
- **"What are the trust boundaries?"** → [SECURITY.md](SECURITY.md).
- **"What are the limitations of this audit?"** → [DISCLAIMER.md](DISCLAIMER.md).
