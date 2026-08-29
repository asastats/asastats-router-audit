# Security Audit Plan — Algorand AMM Router Contract

Adapted from the real-world methodology used by Runtime Verification (Pact Router), Ulam Labs / Vantage Point (Deflex Order-Router), and Trail of Bits' Algorand vulnerability database — combined with current LLM/agentic-audit practice.

---

## Phase 0 — Scoping & Preparation

- [ ] **Freeze code.** Tag the exact commit under audit. No changes mid-audit outside a formal change log.
- [ ] **Define scope explicitly.** In-scope: router contract (approval + clear-state programs), any subroutines it calls, box storage schema, ABI spec. Out of scope (usually): deployment scripts, off-chain quote engine, frontend — but document the boundary since router bugs often hide at that boundary.
- [ ] **Document trust assumptions — this is the single highest-leverage question for a router:**
  - Are the pool app IDs the router can call **hardcoded/whitelisted**, or does the router accept **caller-supplied pool app IDs** at call time?
  - If caller-supplied: what validates that a given app ID is actually a legitimate, audited pool and not an attacker-deployed fake pool that mimics the real pool's interface? This is the router-equivalent of Ethereum's "fake token/fake pair" router exploits and is the #1 thing to nail down before anything else.
- [ ] **Gather artifacts:** architecture diagram, full ABI (`.arc4.json` if used), admin/privileged-role list, upgrade/delete authority, box storage layout, existing test suite, prior audits of the underlying pool contracts (if the router builds on already-audited pools, get those reports too — you're only auditing the composition layer).

## Phase 1 — Automated Static Analysis

- [ ] Run **Tealer** (`crytic/tealer`) against the compiled TEAL — CFG-level detectors for rekeying, close-out, fee, and group-structure issues.
- [ ] Run the **Trail of Bits Algorand vulnerability checklist** (the 11 "Not So Smart Contracts" patterns: rekeying, unchecked fees, missing field validation, access control, group-size checks, clear-state handling, etc.) against the PyTeal/Algorand Python source.
- [ ] If compiling with Puya/Algorand Python, note the compiler version and check its changelog for known codegen issues.
- [ ] Triage every automated finding manually — static tools on TEAL have real false-positive rates; don't ship a report of raw tool output.

## Phase 2 — Manual Line-by-Line Review (Algorand/AVM-specific checklist)

- [ ] **RekeyTo** — verified as zero-address (or an explicitly intended address) on every top-level transaction *and* every inner transaction path, with no branch that skips the check.
- [ ] **CloseRemainderTo / AssetCloseTo** — same treatment; an unchecked close field can drain the router's account balance in a single transaction.
- [ ] **GroupSize / GroupIndex assumptions** — can an attacker pad, reorder, or extend the transaction group to smuggle in unexpected transactions the router doesn't validate?
- [ ] **OnCompletion coverage** — every `OnComplete` value (NoOp, OptIn, CloseOut, UpdateApplication, DeleteApplication) explicitly handled and matched to intended behavior; no implicit fallthrough that grants unintended access.
- [ ] **Inner-transaction fee handling** — is fee pooling correctly budgeted across the multi-hop swap? Can an attacker force excess inner-txn calls to drain the router's ALGO balance via fees (a DoS vector distinct from, but related to, the MBR issue below)?
- [ ] **Minimum Balance Requirement (MBR) accounting** — walk every code path that creates boxes or opts into assets. Confirm nothing can *permanently* inflate the app account's MBR past its funded balance (this is exactly the bug Ulam Labs found in Deflex's router — it bricked the contract for ~24 hours).
- [ ] **Asset ID / App ID reference validation** — every asset/app ID used is checked against `Txn.Assets` / `Txn.Applications` / `Txn.Accounts` arrays as required by the AVM, not assumed.
- [ ] **Box storage** — access control on reads/writes, box-name collision resistance, and who funds box MBR.
- [ ] **Admin / upgrade authority** — who can call `update`/`delete`; is it a single key, multisig, or timelocked? Document the centralization risk explicitly, even if by design.

## Phase 3 — Router/AMM Business-Logic Review

- [ ] **Path/pool validation** (see Phase 0): confirm the router cannot be tricked into routing through an attacker-supplied fake pool that returns manipulated exchange data.
- [ ] **Atomicity of multi-hop swaps** — confirm the entire route is one atomic inner-transaction group; a partial-failure state must not be reachable.
- [ ] **Slippage/minimum-output enforcement** — is it per-hop, aggregate-only (like Deflex), or both? If aggregate-only, confirm an attacker can't manipulate an *intermediate* hop's price within an atomic group in a way that still clears the final aggregate check while extracting value (sandwich-on-intermediate-hop risk).
- [ ] **Price/oracle trust** — does the router trust each pool's spot-reported price live, in the same atomic group as the swap? If so, is that price manipulable within the group before the router reads it (flash-swap-style manipulation)?
- [ ] **Quote deadline/expiry** — off-chain-computed routes should expire; confirm on-chain enforcement, not just an off-chain UI convention.
- [ ] **Rounding direction** on every division in fee and output calculations — must always favor the protocol/pool, never the user, or value leaks per-swap.
- [ ] **Reentrancy-analogue via inner transactions** — can an inner-txn call from a pool call back into the router mid-swap and observe/mutate state inconsistently?

## Phase 4 — Dynamic / Simulation Testing

- [ ] Build a Python-based simulated environment (AlgoKit LocalNet + `algokit-utils`, mirroring Runtime Verification's approach on Pact) that exercises **every ABI endpoint — privileged and non-privileged** — including interaction with mocked pool contracts.
- [ ] Property-based/fuzz testing on the numeric routines (multi-hop output calculation, fee math) for overflow, precision loss, and rounding-direction violations.
- [ ] Adversarial scenario tests: malformed groups, wrong group size, fake pool app IDs, boundary MBR values, repeated box writes.

## Phase 5 — AI-Assisted Second Pass (complementary, not a replacement)

- [ ] Run an LLM-based review (e.g., Claude, or a multi-agent framework in the style of LLM-SmartAudit) over the PyTeal/Algorand Python source plus the ABI spec, explicitly prompted against the Phase 2/3 checklist items above.
- [ ] Cross-check AI-flagged findings against the manual/static-tool findings from Phases 1–4. Treat *divergences* — things the AI flagged that the human pass didn't, or vice versa — as worth a dedicated re-review; current LLM auditors still carry meaningful false-positive and false-negative rates on real-world code, even where benchmark F1 scores look high.
- [ ] Best uses in practice: fast first-pass triage on large diffs, generating additional adversarial test scenarios, and checking that the ABI documentation actually matches the implemented code.

## Phase 6 — Reporting & Remediation

- [ ] Classify every finding: Critical / High / Medium / Low / Informational, each with a proof-of-concept and concrete remediation.
- [ ] Fix-review pass: re-run Phases 1 and 2 against the diff only, don't assume a fix doesn't introduce a new issue.
- [ ] For a router controlling meaningful TVL, consider a second, independent firm for a follow-up review — this is standard practice on Algorand (Deflex and Folks Finance both used multiple independent auditors on the same codebase).

## Phase 7 — Post-Deployment

- [ ] Bug bounty program scoped explicitly to the router and its pool-interaction boundary.
- [ ] Monitoring for anomalies: unexpected box/MBR growth, repeated fee-draining call patterns, swaps clearing aggregate slippage with abnormal intermediate-hop pricing.
- [ ] Documented incident-response runbook and pause/upgrade procedure, with authority and multisig thresholds specified in advance.

---

### Reference audits and tools cited above
- Pact Router audit (Runtime Verification): https://github.com/runtimeverification/publications/blob/main/reports/smart-contracts/Pact_Fi_Router.pdf
- Pact AMM audit (Runtime Verification): https://runtimeverification.com/blog/runtime-verification-audits-pact-s-amm
- Deflex audit case study (Ulam Labs): https://www.ulam.io/blog/ensuring-security-with-smart-contract-audits-a-case-study-with-deflex
- Algorand ecosystem audit collection: https://github.com/blockshake-io/algorand-ecosystem-audits
- Trail of Bits "Not So Smart Contracts" (Algorand): https://github.com/crytic/building-secure-contracts/tree/master/not-so-smart-contracts/algorand
- Tealer static analyzer: https://github.com/crytic/tealer
- Trail of Bits Algorand vulnerability-scanner skill: https://agentskills.so/skills/trailofbits-skills-algorand-vulnerability-scanner
