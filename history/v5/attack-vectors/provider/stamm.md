# Attack Vectors: STAMM AMM Provider Integration (v5)

## 1. Attack Vector Overview
The STAMM AMM protocol utilizes multi-tier constant-product pools with dynamic tier allocations, budget applications, and notification hubs.

---

## 2. Specific Vectors & Evaluations

### V-STAMM-01: Fake STAMM Pool Application ID
- **Attack:** An attacker passes a malicious contract ID claiming to be a STAMM pool.
- **Evaluation:** `_stamm_leg` enforces `_assert_created_by(leg.app.as_uint64(), TemplateVar[Bytes]("STAMM_POOL_CREATORS"))`. Only pools created by official STAMM factory accounts are callable.
- **Verdict:** **DEFENDED.**

### V-STAMM-02: Opup Budget Manipulation
- **Attack:** A caller passes a huge `opups` parameter to force the router to spawn dozens of inner transactions.
- **Evaluation:** `_swap_leg` strictly asserts `assert leg.opups.as_uint64() <= MAX_STAMM_OPUPS` (where `MAX_STAMM_OPUPS = 8`), capping inner calls within safe operational parameters.
- **Verdict:** **DEFENDED.**

### V-STAMM-03: Multi-Tier Deposit Split Corruption
- **Attack:** The split array across STAMM liquidity tiers does not sum to the deposited input.
- **Evaluation:** `_stamm_tier_amounts` constructs the split encoding, and STAMM pools independently assert that tier amounts equal the input payment.
- **Verdict:** **DEFENDED.**
