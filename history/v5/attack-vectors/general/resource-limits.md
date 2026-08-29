# Attack Vectors: AVM Resource Limits & Opcode Budgets (v5)

## 1. Attack Vector Overview
The AVM limits single application calls to 700 opcode units and restricts a single transaction to at most 8 external array references (accounts, assets, apps, boxes). Long multi-hop routes risk hitting these ceilings.

---

## 2. Specific Vectors & Evaluations

### V-RES-01: Opcode Budget Exhaustion on Multi-Hop Swaps
- **Attack:** An attacker constructs a complex 3-leg route through expensive AMMs (e.g., STAMM multi-tier) causing execution to exceed the available opcode budget.
- **Evaluation:**
  - Opcode budgets pool across the group at 700 units per application call.
  - The router includes `pool_budget()` calls where needed.
  - STAMM legs are capped at `MAX_STAMM_OPUPS = 8` to bound inner calls.
  - Real opcode fuzzing tests (`tests/test_real_opcode_fuzz.py`) confirm all valid production routes stay comfortably below budget.
- **Verdict:** **DEFENDED.**

### V-RES-02: Reference Array Overflow (8-Reference Limit)
- **Attack:** A route attempts to touch more than 8 unique accounts/assets/apps in a single call.
- **Evaluation:** The off-chain group builder (`router/legs.py`) calculates exact reference requirements and refuses 4-leg routes that exceed the 8-reference limit. All routed transactions fit within AVM bounds.
- **Verdict:** **DEFENDED.**

### V-RES-03: Group Size Limit (16-Transaction Group Bound)
- **Attack:** Multi-route split execution exceeds the 16-transaction protocol limit.
- **Evaluation:** The quote allocator enforces a strict group budget constraint (`TestQuoting::test_a_quote_respects_the_group_budget`), preventing the construction of oversized transaction groups.
- **Verdict:** **DEFENDED.**
