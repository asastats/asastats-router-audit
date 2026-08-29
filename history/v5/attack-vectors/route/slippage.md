# Attack Vectors: Slippage & Floor Enforcement (v5)

## 1. Attack Vector Overview
Slippage protection ensures users receive at least their agreed-upon minimum output. If slippage parameters are manipulated, sandwich bots or compromised frontends can extract trade value.

---

## 2. Specific Vectors & Evaluations

### V-SLIP-01: Widget Zero Floor Insertion
- **Attack:** A malicious widget passes `minimum_received = 0` to execute a trade at a predatory rate.
- **Evaluation:** Public `route` and `route3` methods take no `minimum_received` parameter. The floor is read directly from the quote signer's co-signed transaction note via `_signed_floor()`.
- **Verdict:** **DEFENDED.**

### V-SLIP-02: Intermediate Leg Manipulation (Aggregate Slippage Drift)
- **Attack:** An attacker manipulates an intermediate leg's price while keeping total output marginally above the aggregate floor.
- **Evaluation:** Realised output from every leg is measured on-chain. Aggregate group output is strictly asserted against the backend-signed quote floor (`_group_paid() >= minimum_received`).
- **Verdict:** **DEFENDED.**

### V-SLIP-03: Stale Quote Submission (Expired Floor)
- **Attack:** An attacker holds a signed quote and submits it hours later when market prices have moved drastically.
- **Evaluation:** The co-signed authorisation transaction carries a network-level `lastValid` round. Algorand consensus rejects any transaction group submitted after `lastValid`, invalidating stale quotes automatically.
- **Verdict:** **DEFENDED.**
