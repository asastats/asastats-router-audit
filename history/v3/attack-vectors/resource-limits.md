# Attack Vectors: Resource Limits & Denial of Service

## Overview
The Algorand Virtual Machine (AVM) enforces strict resource bounds:
- 16 transactions per atomic group
- 8 foreign array references per application transaction
- 700 opcode units per application call base budget
- Minimum Balance Requirement (MBR) per account and holding (0.1 ALGO per ASA)

---

### Detailed Attack Vector Analysis

#### AV-RES-01: MBR Griefing via Unbounded Opt-Ins (Finding MBR Draining)
- **Attack Description:** An attacker submits groups that opt the router into thousands of worthless ASAs, consuming 0.1 ALGO MBR per asset until the router's operational balance is exhausted.
- **Risk Level:** HIGH
- **Verdict:** **Defended**
- **Mechanism:** `opt_in_asset()` requires a matching `route()` in the same atomic group (`_routed_in_group`). `route()` immediately closes the holding at the end of the swap (`_opened_in_group`), returning the 0.1 ALGO to the router within the same transaction.

#### AV-RES-02: Opcode Budget Exhaustion via Unbounded STAMM OpUps (Finding M5)
- **Attack Description:** An attacker passes a large `leg.opups` value on non-STAMM legs or exceeds the AVM compute ceiling, causing execution to run out of opcode budget.
- **Risk Level:** MEDIUM
- **Verdict:** **Patched**
- **Mechanism:**
  - Non-STAMM legs strictly assert `leg.opups.native == 0`.
  - STAMM legs enforce `leg.opups.native <= MAX_STAMM_OPUPS` where `MAX_STAMM_OPUPS = 8`.
  - Dead / unreachable budget code in `_swap_leg` has been cleanly removed in v3.

#### AV-RES-03: Reference Array Overflow (8-Reference Limit)
- **Attack Description:** A multi-hop route requests more than 8 foreign accounts, assets, apps, and boxes in a single application call, failing AVM validation.
- **Risk Level:** HIGH
- **Verdict:** **Defended by Design**
- **Mechanism:** Routes are capped at 3 legs; STAMM legs (which consume budget app, opup app, pool app, hub, and box references) are restricted to 2-leg routes to ensure all references fit within the 8-slot limit.

#### AV-RES-04: Box Storage Inflation DoS
- **Attack Description:** An attacker attempts to write boxes into the router contract account to inflate MBR.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:** The smart router contract uses zero box storage. All operational state is held in fixed global state schema (`UInt64` and `Bytes`), immune to box MBR inflation.
