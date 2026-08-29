# Incorporation of Independent Analyses

The v4 audit incorporated three independent analyses of the STAMM audit applied to a router context. This file documents how each analysis was used.

## analysis1.md — "Critical attack vectors and optimizations for an Algorand AMM router"

### Headline contributions

1. **MBR draining via uncontrolled opt-in.** analysis1 highlighted that if a router automatically opts into any ASA passed in the transaction group, an attacker can drain its operational ALGO. **This vector was already covered** by the v3 audit (M-class invariant `accrued + float isolation`), and is re-verified in v4 in `attack-vectors/general/mbr.md`.

2. **Opcode budget exhaustion.** analysis1 noted that multi-hop routes can exceed the 700-opcode budget. **Already covered** by the v3 audit (M5 STAMM opup sizing), and re-verified in v4 in `attack-vectors/general/resource-limits.md`.

3. **Application ID spoofing.** analysis1 emphasised that the router must cryptographically verify that any target pool was deployed by the official factory. **Already covered** by the v3 audit (M4 provider authentication), and re-verified in v4 for MWPT in `attack-vectors/pact/mwpt.md §MWPT-FACTORY-03`.

4. **Fee pooling exploits.** analysis1 noted that pooled fees can be hijacked. **Already covered** by the v3 audit (`_assert_group_is_clean` scans all transactions), re-verified in v4.

5. **Dust accumulation.** analysis1 noted dust can disrupt exact-amount-out routing. **Already covered** by the v3 audit (final sweep exemption in `convert_and_distribute`), re-verified in v4.

6. **Inner transaction isolation.** analysis1 noted that inner transaction state changes must be strictly isolated. **Already covered** by balance-delta measurement, re-verified in v4.

### What was new from analysis1

- The framing of "MBR draining" as a *first-class* concern (rather than a sub-concern of resource limits) was useful for organising the v4 attack vectors.
- The reminder that "the router should either require the caller to cover the MBR, tear down the local state immediately after the swap, or strictly whitelists assets" is reflected in the v4 attack vectors (`_pay_out` closes holdings).

### What was NOT covered by analysis1

- Weighted-pool dynamics (MWPT) — analysis1 focused on general router concerns, not specific pool types.
- Multi-hop conservation across heterogeneous pools — only briefly mentioned.
- Formal verification approach — not mentioned.

---

## analysis2.md — "Improvements and extra checks for cross-AMM routers"

### Headline contributions

1. **Attack-vector matrix expansion.** analysis2 systematically expanded the STAMM pool-focused vectors into aggregator-specific categories (path manipulation, multi-hop correctness, external call risks, temporary fund holding, DoS via resource limits). This shaped the v4 attack-vectors subdirectory structure.

2. **Algorand platform-specific hardening.** analysis2 referenced Trail of Bits' "Not So Smart Contracts" Algorand section, official guidelines, and the DevRel security best-practices guide. This informed the v4 audit plan §1 and §2 (static analysis + manual review).

3. **Arithmetic and invariant checks.** analysis2 noted that STAMM's 128-bit work is strong for a single pool, but extending to multi-pool composition requires multiplicative overflow / underflow / precision loss analysis across hops with differing decimals. This informed the v4 attack-vectors/route/conservation.md and the verification of MWPT weight asymmetry (M1).

4. **Economic / MEV vectors.** analysis2 noted that even though Algorand reduces sandwich attacks, route selection can introduce spot-price manipulation risk. This is documented in v4 attack-vectors/general/economic.md.

5. **Process improvements.** analysis2 suggested:
   - Human expert review by Algorand-experienced auditors
   - Property-based / fuzz testing against real mainnet pool states
   - Formal invariants
   - Bytecode verification after compilation
   - Integration test matrix against every supported AMM interface
   - Bug bounty + continuous monitoring
   - Explicit scope document with exclusions

The v4 audit incorporates all of these in `audit-coverage.md` and the test tier coverage.

6. **Practical checklist.** analysis2 provided an immediate checklist: inventory external call sites, post-condition asserts after every leg, factory-derived pool addresses, etc. All addressed by the v3 audit and re-verified in v4.

7. **ARC-4 encoding validation risks.** analysis2 documented the Puya security bulletin (October 2025) about fixed-length type overflow, dynamic-array length-prefix mismatches, etc. This informed the v4 verification that `puyapy 5.9.0` includes the post-October-2025 automatic length checks (v3 I3, re-verified).

### What was new from analysis2

- The specific recommendation to use **BigUint** for intermediate products where needed, and to prove (semi-formally) that key quantities stay in safe ranges. This informed M1.
- The recommendation to use **typed ABI parameters** (`gtxn.PaymentTransaction` / `abi.PaymentTransaction`) over hard-coded group indexes. The router already does this.
- The reminder that **ClearState is especially dangerous** (the contract is incentivized never to fail, so never rely on the presence or validity of ABI arguments during ClearState). The router's ClearState program is `pushint 1; return`, so this is not relevant.

### What was NOT covered by analysis2

- Weighted-pool dynamics (MWPT) — analysis2 focused on cross-AMM aggregators in general, not specific pool types.
- The off-chain ↔ on-chain curve drift problem (M1).
- The implicit trust in off-chain vault discovery (L2).

---

## analysis3.md — "Critical gaps NOT covered (high impact)"

### Headline contributions

analysis3 went beyond analysis1 and analysis2 to identify **gaps in the existing audits** that should be added. The v4 audit incorporates all of analysis3's recommendations:

1. **Cross-Protocol State Desynchronization (2.1)** — "Pool state (read) != actual swap outcome." **Already covered** by balance-delta measurement; re-verified for MWPT in `attack-vectors/pact/mwpt.md`.

2. **Re-Entrancy via External App Calls (2.2)** — Algorand-specific form of reentrancy via external app calls or grouped transactions. **Already covered** by local-frame accounting (L3 accepted by design); re-verified for MWPT in `attack-vectors/general/reentrancy.md`.

3. **Cross-Hop Slippage Drift (2.3)** — "Each hop satisfies `output >= min_per_hop`, but `final_output < global_min`." **Already covered** by the floor mechanism (asserts aggregate floor, not per-hop); re-verified in `attack-vectors/route/slippage.md`.

4. **Liquidity Mirage Attacks (2.4)** — Attacker temporarily inflates reserves to manipulate routing. **Mostly not applicable** on Algorand (no mempool, no flash loans); documented in `attack-vectors/general/economic.md`.

5. **Route Cycles / Infinite Value Bleed (2.5)** — User supplies a cyclic route. **Already covered** by route sanitisation (M1 v3, pairwise distinct assets).

6. **Router Balance Contamination (2.6)** — Residual balances from previous swaps affect next user. **Already covered** by balance-delta measurement (only delta matters, not absolute balance).

7. **Failure Atomicity Across External Calls (2.7)** — Atomic groups ≠ safe logic. **Already covered** by atomicity guarantees; re-verified in `attack-vectors/general/reentrancy.md`.

8. **External Pool Upgrade Risk (2.8)** — Whitelisted pool upgraded or proxied. **Already covered** by creator pinning (Pact, STAMM) and whitelist curation (AlgoFi); residual risk documented in DISCLAIMER.md §5.4.

9. **Fee-on-Transfer / Non-Standard Tokens (3.1)** — Clawback/freeze logic. **Not applicable** for the current routers; the engine filters for non-frozen assets.

10. **Group-Level Fee Exploits (3.2)** — Attacker adds high-fee txns. **Already covered** by `_assert_group_is_clean` and `route_fee` ceiling.

11. **Box / Storage DoS (3.3)** — Attacker inflates storage. **Not applicable** — router uses no direct box storage.

12. **Differential Testing Against Real Routers (4.1)** — Compare against Folks, Pact, Deflex, etc. **Partially done** in `tests/test_curves_against_chain.py` and mainnet-state verification.

13. **Adversarial Path Fuzzing (4.2)** — Random paths, malicious pool mixes, extreme decimals. **Already covered** by Hypothesis stateful fuzzing.

14. **Symbolic Multi-Hop Execution (4.3)** — KAVM, etc. **Not done** — formal verification is out of scope for this AI audit.

15. **Economic Stress Simulation (4.4)** — Low liquidity, high slippage, repeated routing. **Partially done** via benchmark runs in `router/benchmarks/`.

16. **"Malicious Pool Harness" (4.5)** — Fake pools that return wrong values, steal funds, revert inconsistently. **Already covered** by adversarial pool simulations (`MODE_*`); recommended extension for MWPT.

### What was new from analysis3

- The "malicious pool harness" framing — explicitly tested adversarial pool behaviours. The router's `tests/test_contract_localnet.py` does this.
- The "next-level audit checklist" — useful for prioritising improvements. Items already covered by the router are checked off; the remainder are in scope for human follow-up.
- The reminder that "STAMM proves correctness of a system you control; your router interacts with systems you do NOT control." This is the core insight of the v4 audit.

### What was NOT covered by analysis3

- Specific MWPT attack vectors (the v4 audit adds 27).
- Specific M1 finding about weighted-pool drift.
- Specific L2 finding about implicit vault trust.

---

## Summary

All three independent analyses were incorporated into the v4 audit. analysis1 and analysis2 provided a baseline of attack vectors that the v3 audit had already covered; analysis3 highlighted gaps that were mostly addressed by the v3 patches, with a few new MWPT-specific vectors that became the v4 findings.

The **unique v4 contribution** beyond the three analyses is the **27 MWPT-specific attack vectors** in `attack-vectors/pact/mwpt.md`, the M1 finding about weighted-pool drift, and the L2 finding about implicit vault trust.
