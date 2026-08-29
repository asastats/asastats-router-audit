# [INFORMATIONAL] I4: Dynamic Minimum Balance Accounting

## Description
In `_held(0)`, the contract computes spendable ALGO balance using:
```python
Global.current_application_address.balance - Global.current_application_address.min_balance
```
Using the dynamic `min_balance` property rather than a hardcoded constant ensures that changes to network minimum balance requirements or temporary holding MBR adjustments do not misreport available funds.

## Status
**Verified Defended by Design.**
