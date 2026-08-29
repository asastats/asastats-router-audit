# Audit Disclaimer

This audit was produced by a multi-agent AI assistant (Claude). It is intended as a thorough first-pass review of the ASA Stats Smart Router contract, with explicit focus on the **Pact MWPT (Managed Weighted Pool)** integration introduced between v3 and v4.

The report should be read with the following caveats in mind.

---

## 1. What this audit *is*

A systematic, evidence-based static and dynamic review of the smart contract at `<router>/contracts/router_app.py` (compiled to `Router.approval.teal` at 4,657 lines), against a structured set of attack vectors adapted from:

- The STAMM AMM Audit (`audit/STAMM-AI-AUDIT-main/`) and its 121-vector methodology.
- Three independent AI analyses (`audit/analysis1.md`, `analysis2.md`, `analysis3.md`).
- The Trail of Bits Algorand vulnerability-scanner skill (`audit/router-audit-v3/algorand-vulnerability-scanner/SKILL.md`).
- The 11-pattern Trail of Bits Algorand vulnerability checklist.
- The Tealer static analyzer (`run_tealer.sh`).
- Three rounds of prior AI audits (`audit/router-audit-v1/`, `v2/`, `v3/`) and their regression tests.

The audit additionally covers the off-chain Python in `router/router/{venues,curves,legs,contract,build,quote,selection,allocate,simulate}.py` to the extent that off-chain behaviour determines on-chain security guarantees — for example, MWPT curve math (`pact_mwpt_out`) and MWPT vault address derivation.

## 2. What this audit *is not*

- It is **not** a formal verification. Formal guarantees of conservation, slippage, or liveness have not been produced; invariants in `docs/invariants.md` are runtime assertions, not machine-checked proofs.
- It is **not** a replacement for human expert review by an Algorand-experienced auditor. The STAMM audit, Deflex, Folks, and Pact audits all combine AI with such human review; this v4 does not.
- It is **not** a guarantee against economic attacks outside the modelled threat model (front-running, governance capture, bridge failures, oracle manipulation on other chains).
- It does **not** audit the deployed bytecode's provenance (a separate bytecode-vs-source diff should be run before any new deployment is signed off).
- It does **not** exhaustively review every external pool contract (Tinyman v2, Pact, STAMM, AlgoFi); the audit verifies how the router interacts with them, not their internal soundness.

## 3. Verdict vocabulary

Every attack vector and every finding resolves to exactly one of the following five verdicts. These terms are used consistently across `findings/`, `attack-vectors/`, and the per-finding writeups.

| Verdict | Meaning |
|---------|---------|
| **Defended** | The code actively prevents the attack. An assert or invariant checks the condition; a test exercises the assert. |
| **Not applicable** | The attack is impossible on Algorand in this design — e.g., no public mempool means classic sandwich is structurally blocked. |
| **By design** | The contract intentionally permits the action; this is an operational decision, not a vulnerability. |
| **Admin-controlled** | The attack succeeds only if the admin acts in bad faith. The audit documents the trust boundary but does not flag it as a code defect. |
| **Accepted** | A documented limitation: the code is correct but the design knowingly permits a residual risk (with rationale). |

Each finding is given a status field: `Patched` (code change), `Verified Defended` (assert exists and was re-verified for v4), `Documented` (entry exists in `docs/invariants.md`), or `Accepted by Design` (residual risk).

## 4. Methodology limitations

- **False-positive / false-negative rate.** Like any LLM-driven audit, this one will both over-flag (treat harmless code as risky) and under-flag (miss subtle interactions). Every finding in `findings/` was manually verified against the compiled TEAL; every attack vector in `attack-vectors/` was triaged. Findings outside this manual verification cycle should be treated with caution.
- **Dynamic testing.** The router has 540+ offline tests, 111 LocalNet integration tests, and 50 mainnet-state tests at the time of writing. This audit inspects those test suites but does not add new tests; the assertion in `test_pact_mwpt.py` is verified to exist but the runtime behaviour is not re-exercised in this audit.
- **Compiler-version dependence.** The audit assumes `puyapy 5.9.0`. A Puya security bulletin (`001-arc4-encoding.md`, October 2025) notes that older versions lacked automatic ARC-4 dynamic-array length validation. If the contract is ever recompiled with an older compiler, ARC-4 boundary checks must be re-verified.
- **Off-chain ↔ on-chain divergence.** The audit verifies that off-chain quoters in `router/router/` match on-chain behaviour for the **MWPT path** (curve math, vault address derivation, foreign-apps array, boxes array, fee sizing). If quoter behaviour diverges from on-chain behaviour, the resulting swap will revert on-chain — which is the *safe* failure mode but wastes fees.
- **Tealer timeouts.** Two Tealer detectors (`group-size-check`, `is-updatable`, `is-deletable`) timed out at the 8 GB ulimit on this 16 GB host and produced `*.covered` files with a static vacuousness proof. The verdict in `tools/tealer-results.md` distinguishes "0 results" (clean) from "covered" (timeout + manual proof). The manual proofs rely on the fact that all 52 dynamic group accesses use `Txn.group_index` arithmetic, which is correct but harder to reason about than absolute indices.

## 5. Residual risks the audit does *not* address

These are explicitly out of scope:

1. **Quote-signer key compromise.** The whole slippage protection collapses to a single trust point. See SECURITY.md §2.
2. **Voucher-signer key compromise.** Same shape: a single key permits unlimited fee discount to anyone. See SECURITY.md §2.
3. **Admin key compromise.** Permits fee redirection within the `MAX_FEE_BPS = 100` ceiling and conversion-pool redirection. Does *not* permit user-fund theft on a per-trade basis. See SECURITY.md §2.
4. **Pact factory creator address divergence.** The MWPT factory address `H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM` is hardcoded in `_pact_leg`. If the upstream Pact team migrates to a new creator (e.g., a new factory version), `_pact_leg` will fall back to the legacy `PACT_SWAP` selector, which the new pool will reject. **No on-chain check verifies the creator address is still correct.**
5. **AlgoFi shutdown dependency.** `ALGOFI_POOLS` list remains relevant only while AlgoFi is shut down. If AlgoFi reactivates, the list becomes stale. See v3 finding I7.

## 6. How to use this report

1. **For the contract author:** Start with [IMPROVEMENTS.md](IMPROVEMENTS.md) — concrete edits to apply. Then [findings/](findings/) for the rationale of each.
2. **For an external auditor:** Start with [REPORT.md](REPORT.md) — consolidated technical view. Then drill into the relevant finding.
3. **For an end user:** Read [IS-IT-SAFE.md](IS-IT-SAFE.md).
4. **For an incident responder:** Read [SECURITY.md](SECURITY.md) §3.
5. **For anyone cross-checking:** Every finding links to its attack vector(s), every attack vector links to the test(s) that exercise it.

---

*This audit reflects the contract source at git revision `5690473` with the working tree as committed 2026-08-22. Any change to `router/contracts/router_app.py`, `router/router/curves.py`, `router/router/legs.py`, or `router/router/venues.py` invalidates this report.*
