# [INFORMATIONAL] I1: Unreachable Dead Code in `_swap_leg` for Non-STAMM OpUps

## Location
`contracts/router_app.py:_swap_leg`

## Description
In `_swap_leg()`, the contract asserted:
```python
if provider != PROVIDER_STAMM:
    assert leg.opups.native == 0, "opups are only for STAMM"
```
Immediately following this, an older code block checked:
```python
if provider != PROVIDER_STAMM and leg.opups.native:
    itxn.ApplicationCall(
        app_id=Application(TemplateVar[UInt64]("STAMM_BUDGET_APP_ID")),
        app_args=(STAMM_BUDGET_PROVIDE, op.itob(leg.opups.native)),
        apps=(Application(TemplateVar[UInt64]("STAMM_OPUP_APP_ID")),),
        fee=0,
    ).submit()
```
Because the assertion enforces `leg.opups.native == 0`, the subsequent `if` condition could never evaluate to True, making the inner application call submission completely unreachable dead code.

## Remediation Applied in v3
The redundant dead code block and associated commentary were removed.
- **Compiled TEAL Impact:** Saved 66 TEAL instructions and 3 basic blocks (reduced from 4,707 to 4,641 lines).
- **Test Impact:** 100% of test suites pass cleanly.

## Status
**Patched in v3 Worktree and Verified.**
