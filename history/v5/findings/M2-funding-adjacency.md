# Finding M2: Funding Transaction Adjacency Enforcement

- **Severity:** Medium
- **Category:** Group Structure / Transaction Validation
- **Location:** `contracts/router_app.py:_input_amount`
- **Origin:** v2 Audit (2026-08-13)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Without strict relative index checks, a funding transaction could be placed non-adjacently within a transaction group, creating ambiguity in multi-route split groupings.

---

## 2. Remediation in Code
Enforced in `_input_amount`:
```python
assert payment.sender == Txn.sender, "input must come from the caller"
assert payment.group_index + 1 == Txn.group_index, "input must immediately precede the route"
```

---

## 3. Verification Evidence
- `TestRoute3Guards::test_route3_requires_the_funding_transaction_to_be_adjacent` passes.
- `TestRouting::test_a_non_adjacent_funding_transaction_is_refused` passes.
