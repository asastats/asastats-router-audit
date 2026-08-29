# Attack Vectors: Economic, MEV & Slippage

## Overview
Economic vectors in decentralized aggregators include sandwich attacks, frontrunning, zero-floor exploits, quote manipulation, and liquidity mirage.

---

### Detailed Attack Vector Analysis

#### AV-ECO-01: Zero-Floor Slippage Exploitation (Finding H1)
- **Attack Description:** A compromised widget or attacker passes `minimum_received = 0`, allowing a searcher/adversary to execute the swap at a predatory exchange rate.
- **Risk Level:** CRITICAL
- **Verdict:** **Patched**
- **Mechanism:** The `minimum_received` parameter was **completely removed from the public method signatures** of `route` and `route3`. The floor is authenticated strictly via a backend-signed note (`_signed_floor`) signed by `quote_signer`.

#### AV-ECO-02: Asserting Route Call Trimming
- **Attack Description:** In a multi-venue split route, an attacker strips the final asserting route call from the group to bypass the slippage floor check on the remaining legs.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** The quote authorization note encodes `FLOOR_ASSERT_INDEX`. Every route call in the group checks that `asserting < Global.group_size` and that the transaction at `asserting` is a genuine route call to this application. If trimmed, all surviving route calls fail immediately.

#### AV-ECO-03: Cross-Hop Slippage Drift & Sandwiching
- **Attack Description:** Sandwiching an intermediate hop in a multi-hop route while still satisfying intermediate bounds.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** The router does not enforce loose per-hop floors; it enforces one strict, aggregate floor on the realized final output tokens delivered to `Txn.sender` via `_group_paid()`.

#### AV-ECO-04: Stale Quote / Group Replay (Finding M2)
- **Attack Description:** An attacker replays an old quoted group when market prices have shifted unfavorably.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** The quote authorization transaction carries a narrow `lastValid` round set by the quote engine. If the network round exceeds `lastValid`, the atomic group is rejected by consensus.
